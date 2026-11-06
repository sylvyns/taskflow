/// Индексы для оптимизации запросов.
///
/// Объявлены отдельно (а не аннотациями), чтобы бенчмарк мог удалить их
/// и создать заново теми же SQL-командами и сравнить скорость запросов.
const Map<String, String> appIndexes = {
  'idx_tasks_project': 'CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks (project_id, deleted_at)',
  'idx_tasks_assignee_status':
      'CREATE INDEX IF NOT EXISTS idx_tasks_assignee_status ON tasks (assignee_id, status, deadline)',
  'idx_tasks_status_priority': 'CREATE INDEX IF NOT EXISTS idx_tasks_status_priority ON tasks (status, priority)',
  'idx_tasks_priority': 'CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks (priority)',
  'idx_tasks_deadline': 'CREATE INDEX IF NOT EXISTS idx_tasks_deadline ON tasks (deadline)',
  'idx_tasks_created_at': 'CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks (created_at)',
  'idx_tasks_deleted_at': 'CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at ON tasks (deleted_at)',
  'idx_members_user': 'CREATE INDEX IF NOT EXISTS idx_members_user ON project_members (user_id)',
  'idx_comments_task': 'CREATE INDEX IF NOT EXISTS idx_comments_task ON comments (task_id)',
  'idx_attachments_task': 'CREATE INDEX IF NOT EXISTS idx_attachments_task ON attachments (task_id)',
  'idx_history_task': 'CREATE INDEX IF NOT EXISTS idx_history_task ON task_history (task_id, id)',
};
