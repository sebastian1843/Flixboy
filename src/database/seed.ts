import { DataSource } from 'typeorm';
import { Category, CategoryType } from '../categories/entities/category.entity';
import {
  Content,
  ContentType,
  ContentStatus,
  AgeClassification,
} from '../content/entities/content.entity';

export async function seedDatabase(dataSource: DataSource) {
  const categoryRepo = dataSource.getRepository(Category);
  const contentRepo = dataSource.getRepository(Content);

  // ── Genres ────────────────────────────────────────────
  const genres = [
    { name: 'Action', slug: 'action', color: '#E50914', displayOrder: 1 },
    { name: 'Comedy', slug: 'comedy', color: '#F5C518', displayOrder: 2 },
    { name: 'Drama', slug: 'drama', color: '#9B59B6', displayOrder: 3 },
    { name: 'Horror', slug: 'horror', color: '#2C3E50', displayOrder: 4 },
    { name: 'Sci-Fi', slug: 'sci-fi', color: '#3498DB', displayOrder: 5 },
    { name: 'Romance', slug: 'romance', color: '#E91E63', displayOrder: 6 },
    { name: 'Thriller', slug: 'thriller', color: '#E67E22', displayOrder: 7 },
    { name: 'Animation', slug: 'animation', color: '#1ABC9C', displayOrder: 8 },
    { name: 'Documentary', slug: 'documentary', color: '#795548', displayOrder: 9 },
    { name: 'Fantasy', slug: 'fantasy', color: '#607D8B', displayOrder: 10 },
    { name: 'Crime', slug: 'crime', color: '#37474F', displayOrder: 11 },
    { name: 'Adventure', slug: 'adventure', color: '#FF9800', displayOrder: 12 },
  ];

  const savedCategories: Category[] = [];
  for (const genre of genres) {
    const existing = await categoryRepo.findOne({ where: { slug: genre.slug } });
    if (!existing) {
      const cat = categoryRepo.create({ ...genre, type: CategoryType.GENRE });
      savedCategories.push(await categoryRepo.save(cat));
    } else {
      savedCategories.push(existing);
    }
  }

  const catMap = Object.fromEntries(savedCategories.map((c) => [c.slug, c]));

  // ── Sample Content ─────────────────────────────────────
  const sampleContent = [
    {
      title: 'Galactic Odyssey',
      synopsis:
        'A crew of astronauts ventures beyond the known universe to find a new home for humanity.',
      type: ContentType.MOVIE,
      releaseYear: 2023,
      durationMinutes: 148,
      ageClassification: AgeClassification.PG13,
      cast: ['Jane Doe', 'Mark Rivers', 'Sofia Chen'],
      directors: ['Alex Turner'],
      languages: ['en', 'es'],
      subtitles: ['es', 'pt', 'fr'],
      isOriginal: true,
      isTrending: true,
      isFeatured: true,
      isNew: true,
      rating: 8.7,
      status: ContentStatus.PUBLISHED,
      categories: [catMap['sci-fi'], catMap['adventure']],
    },
    {
      title: 'Dark Shadows',
      synopsis:
        'A detective hunts a serial killer through the fog-ridden streets of a city paralyzed by fear.',
      type: ContentType.SERIES,
      releaseYear: 2022,
      ageClassification: AgeClassification.TV_MA,
      cast: ['Carlos Vega', 'Leila Hassan'],
      directors: ['Martin Cole'],
      languages: ['en'],
      subtitles: ['es', 'en'],
      isTrending: true,
      isOriginal: true,
      rating: 9.1,
      status: ContentStatus.PUBLISHED,
      categories: [catMap['crime'], catMap['thriller']],
    },
    {
      title: 'The Last Laugh',
      synopsis: "A retired comedian discovers that life's funniest moments are still ahead.",
      type: ContentType.MOVIE,
      releaseYear: 2023,
      durationMinutes: 102,
      ageClassification: AgeClassification.PG,
      cast: ['Henry Grant', 'Tina Moore'],
      directors: ['Sandra Bell'],
      languages: ['en', 'es'],
      subtitles: ['es', 'pt'],
      isNew: true,
      rating: 7.4,
      status: ContentStatus.PUBLISHED,
      categories: [catMap['comedy'], catMap['drama']],
    },
    {
      title: 'Ocean Depths',
      synopsis:
        'An unprecedented look at the mysterious creatures living in the deepest trenches of our oceans.',
      type: ContentType.DOCUMENTARY,
      releaseYear: 2023,
      durationMinutes: 89,
      ageClassification: AgeClassification.G,
      directors: ['Nina Patel'],
      languages: ['en'],
      subtitles: ['es', 'fr', 'de'],
      isFeatured: true,
      isNew: true,
      rating: 8.9,
      status: ContentStatus.PUBLISHED,
      categories: [catMap['documentary']],
    },
  ];

  for (const item of sampleContent) {
    const exists = await contentRepo.findOne({ where: { title: item.title } });
    if (!exists) {
      const content = contentRepo.create(item as any);
      await contentRepo.save(content);
    }
  }

  console.log('✅ Database seeded successfully');
}
