import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Content, ContentType, ContentStatus } from './entities/content.entity';
import { Season } from './entities/season.entity';
import { Episode } from './entities/episode.entity';
import { CreateContentDto } from './dto/create-content.dto';
import { UpdateContentDto } from './dto/update-content.dto';
import { ContentQueryDto } from './dto/content-query.dto';

@Injectable()
export class ContentService {
  constructor(
    @InjectRepository(Content)
    private contentRepository: Repository<Content>,
    @InjectRepository(Season)
    private seasonRepository: Repository<Season>,
    @InjectRepository(Episode)
    private episodeRepository: Repository<Episode>,
  ) {}

  async findAll(query: ContentQueryDto) {
    const {
      type,
      categoryId,
      search,
      page = 1,
      limit = 20,
      isTrending,
      isNew,
      isOriginal,
      isFeatured,
    } = query;

    const qb = this.contentRepository
      .createQueryBuilder('content')
      .leftJoinAndSelect('content.categories', 'category')
      .where('content.status = :status', { status: ContentStatus.PUBLISHED });

    if (type) qb.andWhere('content.type = :type', { type });
    if (search) qb.andWhere('content.title ILIKE :search', { search: `%${search}%` });
    if (categoryId) qb.andWhere('category.id = :categoryId', { categoryId });
    if (isTrending) qb.andWhere('content.isTrending = true');
    if (isNew) qb.andWhere('content.isNew = true');
    if (isOriginal) qb.andWhere('content.isOriginal = true');
    if (isFeatured) qb.andWhere('content.isFeatured = true');

    const [data, total] = await qb
      .orderBy('content.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findOne(id: string): Promise<Content> {
    const content = await this.contentRepository.findOne({
      where: { id },
      relations: ['categories', 'seasons', 'seasons.episodes'],
    });
    if (!content) throw new NotFoundException('Content not found');

    // Sort seasons and episodes
    if (content.seasons) {
      content.seasons.sort((a, b) => a.seasonNumber - b.seasonNumber);
      content.seasons.forEach((season) => {
        if (season.episodes) {
          season.episodes.sort((a, b) => a.episodeNumber - b.episodeNumber);
        }
      });
    }

    return content;
  }

  async findByType(type: ContentType, limit = 20): Promise<Content[]> {
    return this.contentRepository.find({
      where: { type, status: ContentStatus.PUBLISHED },
      relations: ['categories'],
      take: limit,
      order: { createdAt: 'DESC' },
    });
  }

  async findTrending(limit = 20): Promise<Content[]> {
    return this.contentRepository.find({
      where: { isTrending: true, status: ContentStatus.PUBLISHED },
      relations: ['categories'],
      take: limit,
      order: { viewCount: 'DESC' },
    });
  }

  async findNew(limit = 20): Promise<Content[]> {
    return this.contentRepository.find({
      where: { isNew: true, status: ContentStatus.PUBLISHED },
      relations: ['categories'],
      take: limit,
      order: { createdAt: 'DESC' },
    });
  }

  async findOriginals(limit = 20): Promise<Content[]> {
    return this.contentRepository.find({
      where: { isOriginal: true, status: ContentStatus.PUBLISHED },
      relations: ['categories'],
      take: limit,
      order: { rating: 'DESC' },
    });
  }

  async getHomePage() {
    const [trending, newContent, originals, movies, series, documentaries] = await Promise.all([
      this.findTrending(10),
      this.findNew(10),
      this.findOriginals(10),
      this.findByType(ContentType.MOVIE, 10),
      this.findByType(ContentType.SERIES, 10),
      this.findByType(ContentType.DOCUMENTARY, 10),
    ]);

    return {
      rows: [
        { id: 'trending', title: 'Trending Now', contents: trending },
        { id: 'new', title: 'New Releases', contents: newContent },
        { id: 'originals', title: 'Platform Originals', contents: originals },
        { id: 'movies', title: 'Movies', contents: movies },
        { id: 'series', title: 'Series', contents: series },
        { id: 'documentaries', title: 'Documentaries', contents: documentaries },
      ],
    };
  }

  async create(createContentDto: CreateContentDto): Promise<Content> {
    const content = this.contentRepository.create(createContentDto);
    return this.contentRepository.save(content);
  }

  async update(id: string, updateContentDto: UpdateContentDto): Promise<Content> {
    const content = await this.findOne(id);
    Object.assign(content, updateContentDto);
    return this.contentRepository.save(content);
  }

  async remove(id: string): Promise<void> {
    const content = await this.findOne(id);
    await this.contentRepository.remove(content);
  }

  async incrementViewCount(id: string): Promise<void> {
    await this.contentRepository.increment({ id }, 'viewCount', 1);
  }

  // Seasons
  async createSeason(contentId: string, seasonData: Partial<Season>): Promise<Season> {
    await this.findOne(contentId);
    const season = this.seasonRepository.create({ ...seasonData, contentId });
    return this.seasonRepository.save(season);
  }

  async getSeasons(contentId: string): Promise<Season[]> {
    return this.seasonRepository.find({
      where: { contentId },
      relations: ['episodes'],
      order: { seasonNumber: 'ASC' },
    });
  }

  // Episodes
  async createEpisode(seasonId: string, episodeData: Partial<Episode>): Promise<Episode> {
    const season = await this.seasonRepository.findOne({ where: { id: seasonId } });
    if (!season) throw new NotFoundException('Season not found');
    const episode = this.episodeRepository.create({ ...episodeData, seasonId });
    return this.episodeRepository.save(episode);
  }

  async getEpisode(id: string): Promise<Episode> {
    const episode = await this.episodeRepository.findOne({ where: { id } });
    if (!episode) throw new NotFoundException('Episode not found');
    return episode;
  }
}
