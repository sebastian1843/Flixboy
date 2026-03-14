import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';
import { Profile } from '../../profiles/entities/profile.entity';

@Entity('watchlist')
@Index(['profileId', 'contentId'], { unique: true })
export class Watchlist {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Profile, (profile) => profile.watchlist, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'profile_id' })
  profile: Profile;

  @Column({ name: 'profile_id' })
  profileId: string;

  @Column({ name: 'content_id' })
  contentId: string;

  @CreateDateColumn({ name: 'added_at' })
  addedAt: Date;
}
