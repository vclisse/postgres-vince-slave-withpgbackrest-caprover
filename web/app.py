import streamlit as st
import psycopg
import subprocess
import os

def execute_command(command):
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr

def get_postgres_connection():
    return psycopg.connect("dbname=postgres user=postgres password=postgres")

def is_slave_mode():
    return os.path.exists('/var/lib/postgresql/data/standby.signal')

def toggle_mode():
    if is_slave_mode():
        # Passer en mode master
        os.remove('/var/lib/postgresql/data/standby.signal')
        return execute_command('pg_ctl promote -D /var/lib/postgresql/data')
    else:
        # Passer en mode slave
        open('/var/lib/postgresql/data/standby.signal', 'a').close()
        return execute_command('pg_ctl restart -D /var/lib/postgresql/data')

def create_database(db_name):
    return execute_command(f'createdb -U postgres {db_name}')

def import_sql_file(db_name, sql_content):
    temp_file = '/tmp/import.sql'
    with open(temp_file, 'w') as f:
        f.write(sql_content)
    result = execute_command(f'psql -U postgres -d {db_name} -f {temp_file}')
    os.remove(temp_file)
    return result

st.set_page_config(page_title="PostgreSQL Manager", layout="wide")
st.title("PostgreSQL Manager")

# Mode actuel et changement de mode
col1, col2 = st.columns(2)
with col1:
    st.header("Mode Serveur")
    current_mode = "Slave" if is_slave_mode() else "Master"
    st.write(f"Mode actuel : **{current_mode}**")
    if st.button(f"Passer en mode {'Master' if is_slave_mode() else 'Slave'}"):
        success, message = toggle_mode()
        if success:
            st.success("Mode changé avec succès")
        else:
            st.error(f"Erreur: {message}")

# Création de base de données
with col2:
    st.header("Création de Base de Données")
    with st.form("create_db_form"):
        db_name = st.text_input("Nom de la base de données")
        submit_db = st.form_submit_button("Créer la base de données")
        if submit_db and db_name:
            success, message = create_database(db_name)
            if success:
                st.success(f"Base de données {db_name} créée avec succès")
            else:
                st.error(f"Erreur: {message}")

# Import de fichier SQL
st.header("Import de fichier SQL")
with st.form("import_sql_form"):
    target_db = st.text_input("Base de données cible")
    sql_file = st.text_area("Contenu SQL à importer", height=200)
    submit_sql = st.form_submit_button("Importer le SQL")
    if submit_sql and target_db and sql_file:
        success, message = import_sql_file(target_db, sql_file)
        if success:
            st.success("Import SQL réussi")
        else:
            st.error(f"Erreur: {message}")

# Statut de la connexion PostgreSQL
try:
    with get_postgres_connection() as conn:
        st.sidebar.success("✅ Connexion PostgreSQL OK")
except Exception as e:
    st.sidebar.error(f"❌ Erreur de connexion PostgreSQL: {str(e)}")
