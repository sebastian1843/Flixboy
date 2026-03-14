import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { WatchHistory } from '../../watchlist/entities/watch-history.entity';
import { Watchlist } from '../../watchlist/entities/watchlist.entity';

export enum AgeRating {
  KIDS = 'kids', // G - All ages
  TEEN = 'teen', // PG-13
  ADULT = 'adult', // R - 18+
  ALL = 'all', // No restriction
}

@Entity('profiles')
export class Profile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ name: 'avatar_url', nullable: true })
  avatarUrl: string;

  @Column({ name: 'avatar_color', default: '#E50914' })
  avatarColor: string;

  @Column({
    type: 'enum',
    enum: AgeRating,
    default: AgeRating.ALL,
    name: 'age_rating',
  })
  ageRating: AgeRating;

  @Column({ name: 'is_kids_profile', default: false })
  isKidsProfile: boolean;

  @Column({ name: 'pin', nullable: true })
  pin: string;

  @Column({ type: 'jsonb', default: [], name: 'preferred_genres' })
  preferredGenres: string[];

  @Column({ type: 'jsonb', default: [], name: 'preferred_languages' })
  preferredLanguages: string[];

  @Column({ name: 'auto_play_next', default: true })
  autoPlayNext: boolean;

  @Column({ name: 'auto_play_previews', default: true })
  autoPlayPreviews: boolean;

  @ManyToOne(() => User, (user) => user.profiles, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'user_id' })
  userId: string;

  @OneToMany(() => WatchHistory, (history) => history.profile)
  watchHistory: WatchHistory[];

  @OneToMany(() => Watchlist, (watchlist) => watchlist.profile)
  watchlist: Watchlist[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
