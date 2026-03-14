import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';
import { Profile } from '../../profiles/entities/profile.entity';

@Entity('watch_history')
@Index(['profileId', 'contentId'], { unique: false })
export class WatchHistory {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Profile, (profile) => profile.watchHistory, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'profile_id' })
  profile: Profile;

  @Column({ name: 'profile_id' })
  profileId: string;

  @Column({ name: 'content_id' })
  contentId: string;

  @Column({ name: 'episode_id', nullable: true })
  episodeId: string;

  @Column({ name: 'watched_duration', default: 0 })
  watchedDuration: number; // seconds watched

  @Column({ name: 'total_duration', default: 0 })
  totalDuration: number; // total content duration in seconds

  @Column({ name: 'progress_percentage', type: 'decimal', precision: 5, scale: 2, default: 0 })
  progressPercentage: number;

  @Column({ name: 'is_completed', default: false })
  isCompleted: boolean;

  @Column({ name: 'last_watched_at' })
  lastWatchedAt: Date;

  @Column({ type: 'jsonb', nullable: true })
  metadata: {
    quality?: string;
    language?: string;
    subtitle?: string;
    device?: string;
  };

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
