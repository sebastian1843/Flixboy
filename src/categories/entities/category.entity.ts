import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToMany,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Content } from '../../content/entities/content.entity';

export enum CategoryType {
  GENRE = 'genre',
  MOOD = 'mood',
  THEME = 'theme',
  SPECIAL = 'special',
}

@Entity('categories')
export class Category {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  name: string;

  @Column({ unique: true })
  slug: string;

  @Column({ nullable: true })
  description: string;

  @Column({ name: 'icon_url', nullable: true })
  iconUrl: string;

  @Column({ name: 'banner_url', nullable: true })
  bannerUrl: string;

  @Column({ default: '#E50914' })
  color: string;

  @Column({
    type: 'enum',
    enum: CategoryType,
    default: CategoryType.GENRE,
  })
  type: CategoryType;

  @Column({ name: 'display_order', default: 0 })
  displayOrder: number;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @ManyToMany(() => Content, (content) => content.categories)
  contents: Content[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
