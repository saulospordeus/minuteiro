defmodule Minuteiro.Repo.Migrations.AddUserIdToTemplates do
  use Ecto.Migration

  def up do
    alter table(:templates) do
      add :user_id, references(:users, on_delete: :delete_all)
    end

    create index(:templates, [:user_id])

    execute("""
    INSERT INTO users (email, inserted_at, updated_at)
    SELECT 'legacy-import@minuteiro.local', NOW(), NOW()
    WHERE EXISTS (SELECT 1 FROM templates)
      AND NOT EXISTS (SELECT 1 FROM users WHERE email = 'legacy-import@minuteiro.local')
    """)

    execute("""
    UPDATE templates
    SET user_id = (SELECT id FROM users WHERE email = 'legacy-import@minuteiro.local')
    WHERE user_id IS NULL
    """)

    execute("ALTER TABLE templates ALTER COLUMN user_id SET NOT NULL")
  end

  def down do
    drop index(:templates, [:user_id])

    alter table(:templates) do
      remove :user_id
    end
  end
end
