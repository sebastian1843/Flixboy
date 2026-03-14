import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  OneToMany,
  JoinColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Content } from './content.entity';
import { Episode } from './episode.entity';

@Entity('seasons')
export class Season {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'season_number' })
  seasonNumber: number;

  @Column({ nullable: true })
  title: string;

  @Column({ type: 'text', nullable: true })
  synopsis: string;

  @Column({ name: 'release_year', nullable: true })
  releaseYear: number;

  @Column({ name: 'thumbnail_url', nullable: true })
  thumbnailUrl: string;

  @ManyToOne(() => Content, (content) => content.seasons, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'content_id' })
  content: Content;

  @Column({ name: 'content_id' })
  contentId: string;

  @OneToMany(() => Episode, (episode) => episode.season, { cascade: true })
  episodes: Episode[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
