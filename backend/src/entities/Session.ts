import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    UpdateDateColumn,
    OneToMany,
} from 'typeorm';
import { LogEntry } from './LogEntry';

@Entity('sessions')
export class Session {
    @PrimaryGeneratedColumn('increment')
    id: number;

    @Column({ type: 'varchar', length: 255 })
    deviceKey: string;

    @Column({ type: 'varchar', length: 50, default: 'android' })
    platform: string;

    @Column({ type: 'varchar', length: 50 })
    appVersion: string;

    @Column({ type: 'varchar', length: 50 })
    buildNumber: string;

    @CreateDateColumn({ type: 'timestamp' })
    createdAt: Date;

    @UpdateDateColumn({ type: 'timestamp' })
    updatedAt: Date;

    @OneToMany(() => LogEntry, (logEntry: LogEntry) => logEntry.session, { cascade: true })
    logs: LogEntry[];
}

