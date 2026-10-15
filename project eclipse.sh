python -c "
import zipfile

app_code = '''import streamlit as st
import pandas as pd
import plotly.express as px
import sqlite3
import psutil
import datetime
import time

st.set_page_config(page_title='NovaPulse | AI Productivity & Dashboard Hub', page_icon='⚡', layout='wide', initial_sidebar_state='expanded')

st.markdown('''
<style>
    .metric-card { background: rgba(30, 41, 59, 0.7); border: 1px solid rgba(51, 65, 85, 0.8); border-radius: 12px; padding: 16px; margin-bottom: 12px; }
    .badge-done { background-color: #065f46; color: #34d399; padding: 2px 8px; border-radius: 6px; font-size: 12px; }
    .badge-todo { background-color: #374151; color: #d1d5db; padding: 2px 8px; border-radius: 6px; font-size: 12px; }
</style>
''', unsafe_allow_html=True)

DB_FILE = 'novapulse.db'

def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, category TEXT, priority TEXT, status TEXT DEFAULT \"Todo\", created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    c.execute('''CREATE TABLE IF NOT EXISTS habits (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, streak INTEGER DEFAULT 0, last_completed DATE)''')
    conn.commit()
    conn.close()

init_db()

def get_db_connection():
    return sqlite3.connect(DB_FILE)

with st.sidebar:
    st.title('⚡ NovaPulse')
    st.caption('AI-Powered Productivity & Live Monitor')
    app_mode = st.radio('Navigation', ['📊 Dashboard & Telemetry', '✅ Task & Habit Hub', '🤖 AI Assistant & Summarizer'])
    st.divider()
    st.subheader('⚙️ System Status')
    cpu = psutil.cpu_percent()
    mem = psutil.virtual_memory()
    st.progress(cpu / 100, text=f'CPU Load: {cpu}%')
    st.progress(mem.percent / 100, text=f'RAM Used: {mem.percent}%')

if app_mode == '📊 Dashboard & Telemetry':
    st.title('📊 System Telemetry & Productivity Analytics')
    conn = get_db_connection()
    tasks_df = pd.read_sql_query('SELECT * FROM tasks', conn)
    habits_df = pd.read_sql_query('SELECT * FROM habits', conn)
    conn.close()
    
    col1, col2, col3, col4 = st.columns(4)
    tot = len(tasks_df)
    comp = len(tasks_df[tasks_df['status'] == 'Done']) if tot > 0 else 0
    habs = len(habits_df)
    streak = habits_df['streak'].max() if habs > 0 else 0
    
    col1.metric('Total Tasks', tot)
    col2.metric('Completed Tasks', comp, delta=f\"{round((comp/tot)*100, 1)}%\" if tot > 0 else \"0%\")
    col3.metric('Habits Tracked', habs)
    col4.metric('Longest Streak', f'{streak} Days' if streak else '0 Days')
    
    st.divider()
    c1, c2 = st.columns(2)
    with c1:
        st.subheader('Task Completion Status')
        if tot > 0:
            counts = tasks_df['status'].value_counts().reset_index()
            counts.columns = ['Status', 'Count']
            fig = px.pie(counts, values='Count', names='Status', hole=0.45, template='plotly_dark')
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info('No tasks logged yet.')
    with c2:
        st.subheader('Habit Streaks')
        if habs > 0:
            fig2 = px.bar(habits_df, x='name', y='streak', template='plotly_dark')
            st.plotly_chart(fig2, use_container_width=True)
        else:
            st.info('No habits tracked yet.')

elif app_mode == '✅ Task & Habit Hub':
    st.title('✅ Productivity Hub')
    t_tab, h_tab = st.tabs(['📋 Tasks', '🔥 Habits'])
    with t_tab:
        with st.form('new_t', clear_on_submit=True):
            t_name = st.text_input('Task Title')
            cat = st.selectbox('Category', ['Engineering', 'Design', 'Marketing', 'Personal'])
            prio = st.select_slider('Priority', ['Low', 'Medium', 'High', 'Critical'])
            if st.form_submit_button('Add Task') and t_name:
                conn = get_db_connection()
                conn.execute('INSERT INTO tasks (title, category, priority, status) VALUES (?, ?, ?, \"Todo\")', (t_name, cat, prio))
                conn.commit()
                conn.close()
                st.rerun()
        conn = get_db_connection()
        tasks = conn.execute('SELECT id, title, category, priority, status FROM tasks ORDER BY id DESC').fetchall()
        conn.close()
        for tid, title, cat, prio, stat in tasks:
            c1, c2, c3 = st.columns([3, 1, 1])
            c1.markdown(f'**{title}** ({cat} - {prio})')
            if stat != 'Done':
                if c2.button('Done', key=f'd_{tid}'):
                    conn = get_db_connection()
                    conn.execute('UPDATE tasks SET status=\"Done\" WHERE id=?', (tid,))
                    conn.commit()
                    conn.close()
                    st.rerun()
            else:
                c2.write('Completed')
            if c3.button('Delete', key=f'del_{tid}'):
                conn = get_db_connection()
                conn.execute('DELETE FROM tasks WHERE id=?', (tid,))
                conn.commit()
                conn.close()
                st.rerun()
    with h_tab:
        with st.form('new_h', clear_on_submit=True):
            h_name = st.text_input('Habit Name')
            if st.form_submit_button('Track Habit') and h_name:
                conn = get_db_connection()
                conn.execute('INSERT OR IGNORE INTO habits (name, streak) VALUES (?, 0)', (h_name,))
                conn.commit()
                conn.close()
                st.rerun()
        conn = get_db_connection()
        habits = conn.execute('SELECT id, name, streak FROM habits').fetchall()
        conn.close()
        for hid, hname, hstreak in habits:
            c1, c2 = st.columns([3, 1])
            c1.markdown(f'**{hname}** - Streak: {hstreak} days')
            if c2.button('+1 Day', key=f'inc_{hid}'):
                conn = get_db_connection()
                conn.execute('UPDATE habits SET streak = streak + 1 WHERE id=?', (hid,))
                conn.commit()
                conn.close()
                st.rerun()

elif app_mode == '🤖 AI Assistant & Summarizer':
    st.title('🤖 AI Studio')
    text = st.text_area('Input text to summarize:')
    if st.button('Summarize') and text:
        sentences = [s.strip() for s in text.split('.') if len(s.strip()) > 5]
        st.success('Summary:')
        st.write('. '.join(sentences[:2]) + '.')
'''

reqs = '''streamlit>=1.35.0
pandas>=2.0.0
plotly>=5.20.0
psutil>=5.9.0
'''

readme = '''# NovaPulse AI Productivity Hub
Run locally:
1. pip install -r requirements.txt
2. streamlit run app.py
'''

with zipfile.ZipFile('novapulse_app.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('novapulse_app/app.py', app_code)
    z.writestr('novapulse_app/requirements.txt', reqs)
    z.writestr('novapulse_app/README.md', readme)

print('\n[+] Successfully created novapulse_app.zip in your current directory!\n')
"