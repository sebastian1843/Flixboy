import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Season } from './season.entity';

@Entity('episodes')
export class Episode {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'episode_number' })
  episodeNumber: number;

  @Column()
  title: string;

  @Column({ type: 'text', nullable: true })
  synopsis: string;

  @Column({ name: 'duration_minutes' })
  durationMinutes: number;

  @Column({ name: 'thumbnail_url', nullable: true })
  thumbnailUrl: string;

  @Column({ name: 'video_url', nullable: true })
  videoUrl: string;

  @Column({ name: 'video_url_4k', nullable: true })
  videoUrl4k: string;

  @Column({ name: 'video_url_hd', nullable: true })
  videoUrlHd: string;

  @Column({ name: 'video_url_sd', nullable: true })
  videoUrlSd: string;

  @Column({ name: 'release_date', nullable: true })
  releaseDate: Date;

  @Column({ name: 'view_count', default: 0 })
  viewCount: number;

  @ManyToOne(() => Season, (season) => season.episodes, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'season_id' })
  season: Season;

  @Column({ name: 'season_id' })
  seasonId: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
