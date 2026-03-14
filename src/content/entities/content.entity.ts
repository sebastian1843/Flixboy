import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToMany,
  JoinTable,
  OneToMany,
} from 'typeorm';
import { Category } from '../../categories/entities/category.entity';
import { Season } from './season.entity';

export enum ContentType {
  MOVIE = 'movie',
  SERIES = 'series',
  DOCUMENTARY = 'documentary',
  SHORT = 'short',
  SPECIAL = 'special',
}

export enum ContentStatus {
  DRAFT = 'draft',
  PUBLISHED = 'published',
  ARCHIVED = 'archived',
}

export enum AgeClassification {
  G = 'G',
  PG = 'PG',
  PG13 = 'PG-13',
  R = 'R',
  NC17 = 'NC-17',
  TV_Y = 'TV-Y',
  TV_G = 'TV-G',
  TV_PG = 'TV-PG',
  TV_14 = 'TV-14',
  TV_MA = 'TV-MA',
}

@Entity('contents')
export class Content {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  title: string;

  @Column({ name: 'original_title', nullable: true })
  originalTitle: string;

  @Column({ type: 'text' })
  synopsis: string;

  @Column({ name: 'short_synopsis', nullable: true })
  shortSynopsis: string;

  @Column({
    type: 'enum',
    enum: ContentType,
    default: ContentType.MOVIE,
  })
  type: ContentType;

  @Column({
    type: 'enum',
    enum: ContentStatus,
    default: ContentStatus.DRAFT,
  })
  status: ContentStatus;

  @Column({ name: 'release_year' })
  releaseYear: number;

  @Column({ name: 'duration_minutes', nullable: true })
  durationMinutes: number; // For movies

  @Column({
    type: 'enum',
    enum: AgeClassification,
    default: AgeClassification.PG,
    name: 'age_classification',
  })
  ageClassification: AgeClassification;

  @Column({ type: 'decimal', precision: 3, scale: 1, default: 0 })
  rating: number;

  @Column({ name: 'rating_count', default: 0 })
  ratingCount: number;

  @Column({ type: 'simple-array', nullable: true })
  cast: string[];

  @Column({ type: 'simple-array', nullable: true })
  directors: string[];

  @Column({ type: 'simple-array', nullable: true })
  writers: string[];

  @Column({ type: 'simple-array', default: [] })
  languages: string[];

  @Column({ type: 'simple-array', default: [] })
  subtitles: string[];

  @Column({ name: 'thumbnail_url', nullable: true })
  thumbnailUrl: string;

  @Column({ name: 'banner_url', nullable: true })
  bannerUrl: string;

  @Column({ name: 'trailer_url', nullable: true })
  trailerUrl: string;

  @Column({ name: 'video_url', nullable: true })
  videoUrl: string; // For movies

  @Column({ name: 'video_url_4k', nullable: true })
  videoUrl4k: string;

  @Column({ name: 'video_url_hd', nullable: true })
  videoUrlHd: string;

  @Column({ name: 'video_url_sd', nullable: true })
  videoUrlSd: string;

  @Column({ name: 'is_original', default: false })
  isOriginal: boolean; // Platform original content

  @Column({ name: 'is_trending', default: false })
  isTrending: boolean;

  @Column({ name: 'is_featured', default: false })
  isFeatured: boolean;

  @Column({ name: 'is_new', default: false })
  isNew: boolean;

  @Column({ name: 'view_count', default: 0 })
  viewCount: number;

  @Column({ type: 'simple-array', nullable: true })
  tags: string[];

  @Column({ nullable: true })
  country: string;

  @Column({ name: 'production_company', nullable: true })
  productionCompany: string;

  @ManyToMany(() => Category, (category) => category.contents, { eager: true })
  @JoinTable({
    name: 'content_categories',
    joinColumn: { name: 'content_id' },
    inverseJoinColumn: { name: 'category_id' },
  })
  categories: Category[];

  @OneToMany(() => Season, (season) => season.content, { cascade: true })
  seasons: Season[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
