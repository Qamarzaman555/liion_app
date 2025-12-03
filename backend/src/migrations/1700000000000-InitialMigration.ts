import { MigrationInterface, QueryRunner, Table, TableForeignKey, TableIndex } from 'typeorm';

export class InitialMigration1700000000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // Create sessions table
    await queryRunner.createTable(
      new Table({
        name: 'sessions',
        columns: [
          {
            name: 'id',
            type: 'int',
            isPrimary: true,
            isGenerated: true,
            generationStrategy: 'increment',
          },
          {
            name: 'deviceKey',
            type: 'varchar',
            length: '255',
          },
          {
            name: 'platform',
            type: 'varchar',
            length: '50',
            default: "'android'",
          },
          {
            name: 'appVersion',
            type: 'varchar',
            length: '50',
          },
          {
            name: 'buildNumber',
            type: 'varchar',
            length: '50',
          },
          {
            name: 'createdAt',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'updatedAt',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
            onUpdate: 'CURRENT_TIMESTAMP',
          },
        ],
      }),
      true
    );

    // Create log_entries table
    await queryRunner.createTable(
      new Table({
        name: 'log_entries',
        columns: [
          {
            name: 'id',
            type: 'int',
            isPrimary: true,
            isGenerated: true,
            generationStrategy: 'increment',
          },
          {
            name: 'sessionId',
            type: 'int',
          },
          {
            name: 'ts',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'level',
            type: 'varchar',
            length: '50',
          },
          {
            name: 'message',
            type: 'text',
          },
          {
            name: 'createdAt',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
        ],
      }),
      true
    );

    // Create foreign key
    await queryRunner.createForeignKey(
      'log_entries',
      new TableForeignKey({
        columnNames: ['sessionId'],
        referencedColumnNames: ['id'],
        referencedTableName: 'sessions',
        onDelete: 'CASCADE',
      })
    );

    // Create indexes
    await queryRunner.createIndex(
      'log_entries',
      new TableIndex({
        name: 'IDX_log_entries_sessionId_createdAt',
        columnNames: ['sessionId', 'ts'],
      })
    );

    await queryRunner.createIndex(
      'log_entries',
      new TableIndex({
        name: 'IDX_log_entries_level',
        columnNames: ['level'],
      })
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropTable('log_entries');
    await queryRunner.dropTable('sessions');
  }
}

