🚀 Ansible Project: ClickHouse + Vector + Lighthouse

Ansible playbook для автоматической установки и настройки стека аналитики логов: ClickHouse (СУБД), Vector (агент сбора логов) и Lighthouse (веб-интерфейс).

📖 Содержание

Общее описание
Требования
Структура проекта
Инвентарь
Переменные
Play 1: Install ClickHouse
Play 2: Install Vector
Play 3: Install Lighthouse
Шаблон конфигурации Vector
Шаблон конфигурации Lighthouse
Запуск Playbook
Проверка результата
Лицензия

📌 Общее описание

Playbook разворачивает стек на серверах под управлением CentOS 7 и состоит из трёх play:

Install ClickHouse — скачивание RPM-пакетов, установка СУБД, запуск сервиса, создание базы logs и таблицы logs_table.
Install Vector — скачивание RPM-пакета, установка агента и деплой конфигурации из Jinja2-шаблона.
Install Lighthouse — установка Nginx, Git, клонирование репозитория и публикация веб-интерфейса.

Целевые хосты: группы clickhouse и lighthouse из инвентаря.
Пользователь: root (через become).

Upgradability notice
При обновлении версий ClickHouse или Vector сначала останавливайте соответствующий сервис, затем запускайте playbook. Версии фиксируются в group_vars/clickhouse/vars.yml и group_vars/lighthouse/vars.yml.

⚙️ Требования

Ansible >= 2.13 (управляющий узел)
CentOS 7 на целевых хостах (GLIBC 2.17)
Пользователь с sudo без пароля

Software

Компонент | Версия | Назначение
ClickHouse | 22.3.3.44 (LTS) | СУБД
Vector | 0.31.0 | Агент логов
Nginx | из epel-release | Веб-сервер для Lighthouse
Git | из base | Клонирование Lighthouse

Requirements to VM

2 vCPU, 4 ГБ RAM
Открытые порты: 22 (SSH), 8123 (ClickHouse HTTP), 9000 (ClickHouse native), 80 (Lighthouse)

Collections

# requirements.yml
collections:
  - name: ansible.posix
  - name: community.general

Установка:

ansible-galaxy collection install -r requirements.yml

📁 Структура проекта

ansible-project/
├── site.yml
├── requirements.yml
├── cloud-init.yml
├── inventory/
│   └── prod.yml
├── group_vars/
│   ├── clickhouse/vars.yml
│   └── lighthouse/vars.yml
├── templates/
│   ├── vector.toml.j2
│   └── nginx_config.j2
├── clickhouse/          # роль ClickHouse
├── vector-role/         # роль Vector
└── lighthouse/          # роль Lighthouse

🖥 Инвентарь

Файл: inventory/prod.yml

clickhouse:
  hosts:
    clickhouse-01:
      ansible_host: <IP>
      ansible_user: centos

lighthouse:
  hosts:
    lighthouse-01:
      ansible_host: <IP>
      ansible_user: centos

Параметр | Описание
ansible_host | IP-адрес или доменное имя ВМ
ansible_user | Пользователь для SSH

🔧 Переменные

Все переменные, которые можно переопределить, хранятся в group_vars/<group>/vars.yml, а также в таблице ниже.

Name | Default Value | Description
clickhouse_version | 22.3.3.44 | Версия ClickHouse. Поддерживается только 22.x LTS
clickhouse_packages | [clickhouse-client, clickhouse-server, clickhouse-common-static] | Список RPM-пакетов ClickHouse
clickhouse_database | logs | Имя базы данных для логов
clickhouse_table | logs_table | Имя таблицы для логов
vector_version | 0.31.0 | Версия Vector
vector_config_dir | {{ ansible_user_dir }}/vector_config | Директория с конфигурацией Vector
vector_config | {} | Дополнительные параметры конфигурации Vector
lighthouse_git | URL репозитория | Git-репозиторий Lighthouse
lighthouse_root_path | /var/www/lighthouse | Директория для статики Lighthouse
hostvars['clickhouse-dev-1'].ansible_host_internal | — | Внутренний адрес ClickHouse для Lighthouse

📦 Play 1: Install ClickHouse

Параметры play

- name: Install Clickhouse
  hosts: clickhouse
  become: true
  become_user: root

Handlers

Handler | Назначение
Start clickhouse service | Перезапуск clickhouse-server
Ensure systemd is in a clean state | systemctl daemon-reexec

Задачи

1️⃣ Скачивание RPM-пакетов

- name: Get clickhouse distrib
  ansible.builtin.get_url:
    url: "https://packages.clickhouse.com/rpm/lts/{{ item }}-{{ clickhouse_version }}.noarch.rpm"
    dest: "./{{ item }}-{{ clickhouse_version }}.rpm"
  with_items:
    - clickhouse-client
    - clickhouse-server

- name: Get clickhouse distrib
  ansible.builtin.get_url:
    url: "https://packages.clickhouse.com/rpm/lts/clickhouse-common-static-{{ clickhouse_version }}.x86_64.rpm"
    dest: "./clickhouse-common-static-{{ clickhouse_version }}.rpm"

2️⃣ Установка пакетов

- name: Install clickhouse packages
  ansible.builtin.yum:
    name:
      - clickhouse-client-{{ clickhouse_version }}.rpm
      - clickhouse-server-{{ clickhouse_version }}.rpm
      - clickhouse-common-static-{{ clickhouse_version }}.rpm
  notify: Start clickhouse service

3️⃣ Запуск сервиса

- name: Ensure ClickHouse is running
  ansible.builtin.systemd:
    name: clickhouse-server
    state: restarted
    enabled: yes
    daemon_reload: yes
  async: 300
  poll: 5

4️⃣ Ожидание готовности

- name: Wait until ClickHouse responds to queries
  ansible.builtin.command: "clickhouse-client -q 'SELECT 1'"
  register: ch_ready
  until: ch_ready.rc == 0
  retries: 30
  delay: 10
  changed_when: false
  failed_when: false

5️⃣ Создание базы и таблицы

- name: Create ClickHouse database
  ansible.builtin.command: "clickhouse-client -q 'CREATE DATABASE IF NOT EXISTS logs;'"
  register: create_db
  failed_when: create_db.rc != 0 and create_db.rc != 82
  changed_when: create_db.rc == 0

- name: Create ClickHouse table
  ansible.builtin.command: >
    clickhouse-client -q "CREATE TABLE IF NOT EXISTS logs.logs_table
    (timestamp String, message String)
    ENGINE = MergeTree() ORDER BY timestamp;"

📦 Play 2: Install Vector

Параметры play

- name: Install vector
  hosts: clickhouse
  become: true
  become_user: root

Handlers

handlers:
  - name: Restart vector service
    ansible.builtin.service:
      name: vector
      state: restarted

Задачи

1️⃣ Скачивание Vector

- name: Get vector distrib
  ansible.builtin.get_url:
    url: "https://yum.vector.dev/stable/vector-0/x86_64/vector-{{ vector_version }}-1.x86_64.rpm"
    dest: "./vector-{{ vector_version }}.rpm"
    mode: "0644"
  notify: Restart vector service

2️⃣ Установка

- name: Install vector packages
  ansible.builtin.yum:
    name:
      - vector-{{ vector_version }}.rpm
    disable_gpg_check: true

3️⃣ Применение handlers

- name: Flush handlers to restart vector
  ansible.builtin.meta: flush_handlers

4️⃣ Деплой конфигурации

- name: Deploy Vector configuration from template
  ansible.builtin.template:
    src: vector.toml.j2
    dest: /etc/vector/vector.toml
    owner: vector
    group: vector
    mode: '0644'
    validate: /usr/bin/vector validate --config-toml %s
  notify: Restart vector service

📦 Play 3: Install Lighthouse

Параметры play

- name: Install lighthouse
  hosts: lighthouse
  become: true
  become_user: root

Задачи

1️⃣ Скачивание Epel

- name: Install epel-release
  become: true
  ansible.builtin.yum:
    name: epel-release
    state: present

2️⃣ Установка веб-сервера Nginx

- name: Install nginx
  become: true
  ansible.builtin.yum:
    name: nginx
    state: present

3️⃣ Применение шаблона

- name: Configure
  become: true
  ansible.builtin.template:
    src: nginx_config.j2
    dest: /etc/nginx/conf.d/lighthouse.conf
    mode: "0644"

4️⃣ Установка Git

- name: Git Install
  become: true
  ansible.builtin.yum:
    name: git
    state: present

5️⃣ Скачивание с репозитория

- name: Clone repository
  become: true
  ansible.builtin.git:
    repo: '{{ lighthouse_git }}'
    dest: '{{ lighthouse_root_path }}'
    version: master

6️⃣ Запуск сервиса

- name: Start nginx
  become: true
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true

📝 Шаблон конфигурации Vector

Файл: templates/vector.toml.j2

data_dir = "/var/lib/vector/"

[api]
enabled = true
address = "127.0.0.1:8686"

[sources.demo_logs]
type = "demo_logs"
format = "json"
interval = 1

[sinks.clickhouse]
type = "clickhouse"
inputs = ["demo_logs"]
endpoint = "http://localhost:8123"
database = "logs"
table = "logs_table"
skip_unknown_fields = true
auth.strategy = "basic"
auth.user = "default"
auth.password = ""

[sinks.stdout]
type = "console"
inputs = ["demo_logs"]
encoding.codec = "json"

Ключевые параметры

Параметр | Значение | Пояснение
endpoint | http://localhost:8123 | ClickHouse HTTP
skip_unknown_fields | true | Пропуск лишних полей
auth.strategy | basic | Basic Auth для ClickHouse

📝 Шаблон конфигурации Lighthouse

Файл: templates/nginx_config.j2

{
  "clickhouse": {
    "host": "{{ hostvars['clickhouse-dev-1'].ansible_host_internal }}",
    "port": 8123,
    "user": "default",
    "password": ""
  }
}

▶️ Запуск Playbook

Полный запуск

ansible-playbook -i inventory/prod.yml site.yml

Проверка синтаксиса

ansible-playbook -i inventory/prod.yml site.yml --syntax-check

Пробный прогон

ansible-playbook -i inventory/prod.yml site.yml --check --diff

Только ClickHouse

ansible-playbook -i inventory/prod.yml site.yml --start-at-task="Get clickhouse distrib"

Только Vector

ansible-playbook -i inventory/prod.yml site.yml --start-at-task="Get vector distrib"

Только Lighthouse

ansible-playbook -i inventory/prod.yml site.yml --start-at-task="Install epel-release"

✅ Проверка результата

На хосте

# 1. Статус сервисов
sudo systemctl status clickhouse-server
sudo systemctl status vector
sudo systemctl status nginx

# 2. ClickHouse работает?
curl -s http://localhost:8123/ping
# Ok.
clickhouse-client -q "SELECT version();"

# 3. База и таблица созданы?
clickhouse-client --host 127.0.0.1 -q "SHOW DATABASES;"
clickhouse-client --host 127.0.0.1 -q "SHOW TABLES FROM logs;"
clickhouse-client --host 127.0.0.1 -q "DESCRIBE logs.logs_table;"
# timestamp  String
# message    String

# 4. Данные идут?
clickhouse-client --host 127.0.0.1 -q "SELECT count() FROM logs.logs_table;"
sleep 15
clickhouse-client --host 127.0.0.1 -q "SELECT count() FROM logs.logs_table;"
# Счётчик растёт

# 5. Логи Vector
sudo journalctl -u vector -n 20 --no-pager

Lighthouse

Откройте в браузере http://<lighthouse-host>/ — должен отобразиться веб-интерфейс.

📄 Лицензия

Лицензия MIT. Подробнее — в файле LICENSE.