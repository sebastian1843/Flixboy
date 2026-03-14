import { Injectable, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';
import { Content, ContentStatus, ContentType } from '../content/entities/content.entity';
import { Category } from '../categories/entities/category.entity';
import { SearchQueryDto } from './dto/search-query.dto';

@Injectable()
export class SearchService {
  constructor(
    @InjectRepository(Content)
    private contentRepository: Repository<Content>,
    @InjectRepository(Category)
    private categoryRepository: Repository<Category>,
    @Inject(CACHE_MANAGER)
    private cacheManager: Cache,
  ) {}

  async search(dto: SearchQueryDto) {
    const { q, type, categoryId, year, minRating, page = 1, limit = 20 } = dto;

    const qb = this.contentRepository
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.categories', 'cat')
      .where('c.status = :status', { status: ContentStatus.PUBLISHED });

    if (q) {
      qb.andWhere(
        '(c.title ILIKE :q OR c.originalTitle ILIKE :q OR c.synopsis ILIKE :q OR :qTag = ANY(c.tags))',
        { q: `%${q}%`, qTag: q.toLowerCase() },
      );
    }

    if (type) qb.andWhere('c.type = :type', { type });
    if (categoryId) qb.andWhere('cat.id = :categoryId', { categoryId });
    if (year) qb.andWhere('c.releaseYear = :year', { year });
    if (minRating) qb.andWhere('c.rating >= :minRating', { minRating });

    const [data, total] = await qb
      .orderBy('c.rating', 'DESC')
      .addOrderBy('c.viewCount', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit), query: q },
    };
  }

  async autocomplete(
    q: string,
    limit = 8,
  ): Promise<{ id: string; title: string; type: string; thumbnailUrl: string }[]> {
    const cacheKey = `search:autocomplete:${q.toLowerCase()}`;
    const cached = await this.cacheManager.get<any[]>(cacheKey);
    if (cached) return cached;

    const results = await this.contentRepository
      .createQueryBuilder('c')
      .select(['c.id', 'c.title', 'c.type', 'c.thumbnailUrl'])
      .where('c.title ILIKE :q', { q: `%${q}%` })
      .andWhere('c.status = :status', { status: ContentStatus.PUBLISHED })
      .orderBy('c.viewCount', 'DESC')
      .limit(limit)
      .getMany();

    const mapped = results.map((c) => ({
      id: c.id,
      title: c.title,
      type: c.type,
      thumbnailUrl: c.thumbnailUrl,
    }));

    await this.cacheManager.set(cacheKey, mapped, 120);
    return mapped;
  }

  async getPopularSearches(limit = 10): Promise<string[]> {
    const trending = await this.contentRepository.find({
      select: ['title'],
      where: { isTrending: true, status: ContentStatus.PUBLISHED },
      order: { viewCount: 'DESC' },
      take: limit,
    });
    return trending.map((c) => c.title);
  }
}
