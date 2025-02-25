import streamlit as st
import psycopg
import subprocess
import os
from datetime import datetime

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

def get_pg_version():
    try:
        with psycopg.connect("dbname=postgres user=postgres password=postgres") as conn:
            with conn.cursor() as cur:
                cur.execute("SHOW server_version;")
                return cur.fetchone()[0]
    except Exception:
        return "N/A"

def get_db_size():
    try:
        with psycopg.connect("dbname=postgres user=postgres password=postgres") as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT pg_size_pretty(pg_database_size('postgres'));")
                return cur.fetchone()[0]
    except Exception:
        return "N/A"

# Configuration de la page
st.set_page_config(
    page_title="PostgreSQL Manager",
    layout="wide",
    initial_sidebar_state="expanded"
)

# CSS personnalisé
st.markdown("""
<style>
    .status-card {
        padding: 2rem;
        border-radius: 10px;
        margin: 1rem 0;
        text-align: center;
    }
    .status-slave {
        background-color: #2E86C1;
        color: white;
    }
    .status-master {
        background-color: #28B463;
        color: white;
    }
    .header-container {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 1rem;
        background-color: #f0f2f6;
        border-radius: 10px;
        margin-bottom: 2rem;
    }
    .metric-card {
        background-color: white;
        padding: 1rem;
        border-radius: 5px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        margin: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)

# En-tête avec métriques
st.markdown("""
<div class="header-container">
    <h1>PostgreSQL Manager</h1>
    <div style="display: flex;">
        <div class="metric-card">
            <h4>Version PostgreSQL</h4>
            <p>{}</p>
        </div>
        <div class="metric-card">
            <h4>Taille DB</h4>
            <p>{}</p>
        </div>
        <div class="metric-card">
            <h4>Mise à jour</h4>
            <p>{}</p>
        </div>
    </div>
</div>
""".format(get_pg_version(), get_db_size(), datetime.now().strftime("%H:%M:%S")), unsafe_allow_html=True)

# Affichage du statut
current_mode = "Slave" if os.path.exists('/var/lib/postgresql/data/standby.signal') else "Master"
status_class = "status-slave" if current_mode == "Slave" else "status-master"

st.markdown(f"""
<div class="status-card {status_class}">
    <h2>Mode {current_mode}</h2>
    <p>Le serveur fonctionne actuellement en mode {current_mode}</p>
</div>
""", unsafe_allow_html=True)

# Actions principales dans des colonnes
col1, col2 = st.columns(2)

with col1:
    st.markdown("### Gestion du Mode")
    if st.button(f"Passer en mode {'Master' if current_mode == 'Slave' else 'Slave'}", 
                 type="primary" if current_mode == "Slave" else "secondary"):
        success, message = toggle_mode()
        if success:
            st.success("Mode changé avec succès")
        else:
            st.error(f"Erreur: {message}")

with col2:
    st.markdown("### Création de Base de Données")
    with st.form("create_db_form"):
        db_name = st.text_input("Nom de la base de données")
        submit_db = st.form_submit_button("Créer la base de données")
        if submit_db and db_name:
            success, message = create_database(db_name)
            if success:
                st.success(f"Base de données {db_name} créée avec succès")
            else:
                st.error(f"Erreur: {message}")

# Import SQL avec prévisualisation
st.markdown("### Import de fichier SQL")
with st.expander("Développer pour importer du SQL"):
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

# Statut de connexion dans la barre latérale avec style
try:
    with get_postgres_connection():
        st.sidebar.markdown("""
            <div style="padding: 1rem; background-color: #28B463; color: white; border-radius: 5px;">
                ✅ Connexion PostgreSQL active
            </div>
        """, unsafe_allow_html=True)
except Exception as e:
    st.sidebar.markdown(f"""
        <div style="padding: 1rem; background-color: #E74C3C; color: white; border-radius: 5px;">
            ❌ Erreur de connexion: {str(e)}
        </div>
    """, unsafe_allow_html=True)
