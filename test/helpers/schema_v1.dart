/// Схема первой версии БД (до добавления tasks.priority).
/// Используется в тесте миграции v1 → v2.
const List<String> schemaV1 = [
  '''
CREATE TABLE users (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  registered_at INTEGER NOT NULL
)''',
  '''
CREATE TABLE projects (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  end_date INTEGER NULL,
  status TEXT NOT NULL DEFAULT 'active'
)''',
  '''
CREATE TABLE project_members (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member',
  joined_at INTEGER NOT NULL,
  UNIQUE (project_id, user_id)
)''',
  '''
CREATE TABLE tasks (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  project_id INTEGER NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
  assignee_id INTEGER NULL REFERENCES users (id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'todo',
  deadline INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
)''',
  '''
CREATE TABLE comments (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
  author_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL
)''',
  '''
CREATE TABLE attachments (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  size_bytes INTEGER NULL,
  added_at INTEGER NOT NULL
)''',
  '''
CREATE TABLE task_history (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
  change_type TEXT NOT NULL,
  previous_status TEXT NULL,
  new_status TEXT NULL,
  previous_assignee_id INTEGER NULL,
  new_assignee_id INTEGER NULL,
  changed_by INTEGER NULL REFERENCES users (id) ON DELETE SET NULL,
  changed_at INTEGER NOT NULL,
  is_undone INTEGER NOT NULL DEFAULT 0 CHECK (is_undone IN (0, 1))
)''',
];

/// Данные «старой» версии приложения.
const List<String> seedV1 = [
  "INSERT INTO users (id, name, email, registered_at) VALUES (1, 'Анна', 'anna@test.io', 1700000000)",
  "INSERT INTO projects (id, name, description, created_at, status) VALUES (1, 'Наследие', 'v1', 1700000000, 'active')",
  "INSERT INTO project_members (project_id, user_id, role, joined_at) VALUES (1, 1, 'owner', 1700000000)",
  "INSERT INTO tasks (id, title, description, project_id, assignee_id, status, deadline, created_at, updated_at) "
      "VALUES (1, 'Старая задача', 'из первой версии', 1, 1, 'todo', 1900000000, 1700000000, 1700000000)",
  "INSERT INTO tasks (id, title, description, project_id, assignee_id, status, deadline, created_at, updated_at) "
      "VALUES (2, 'Готовая задача', '', 1, 1, 'done', 1700500000, 1700000000, 1700100000)",
  "INSERT INTO task_history (task_id, change_type, new_status, changed_by, changed_at) "
      "VALUES (1, 'created', 'todo', 1, 1700000000)",
  "INSERT INTO comments (task_id, author_id, body, created_at) VALUES (1, 1, 'Комментарий v1', 1700000100)",
];
