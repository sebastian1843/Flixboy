import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Watchlist } from './entities/watchlist.entity';
import { WatchHistory } from './entities/watch-history.entity';
import { ContentService } from '../content/content.service';
import { UpdateWatchProgressDto } from './dto/update-watch-progress.dto';

@Injectable()
export class WatchlistService {
  constructor(
    @InjectRepository(Watchlist)
    private watchlistRepository: Repository<Watchlist>,
    @InjectRepository(WatchHistory)
    private watchHistoryRepository: Repository<WatchHistory>,
    private contentService: ContentService,
  ) {}

  // ── Watchlist ──────────────────────────────────────────
  async getWatchlist(profileId: string, page = 1, limit = 20) {
    const [data, total] = await this.watchlistRepository.findAndCount({
      where: { profileId },
      order: { addedAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });

    // Enrich with content details
    const enriched = await Promise.all(
      data.map(async (item) => {
        try {
          const content = await this.contentService.findOne(item.contentId);
          return { ...item, content };
        } catch {
          return item;
        }
      }),
    );

    return {
      data: enriched,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async addToWatchlist(profileId: string, contentId: string): Promise<Watchlist> {
    await this.contentService.findOne(contentId); // validate exists

    const existing = await this.watchlistRepository.findOne({
      where: { profileId, contentId },
    });
    if (existing) throw new ConflictException('Content already in watchlist');

    const item = this.watchlistRepository.create({ profileId, contentId });
    return this.watchlistRepository.save(item);
  }

  async removeFromWatchlist(profileId: string, contentId: string): Promise<void> {
    const item = await this.watchlistRepository.findOne({
      where: { profileId, contentId },
    });
    if (!item) throw new NotFoundException('Item not in watchlist');
    await this.watchlistRepository.remove(item);
  }

  async isInWatchlist(profileId: string, contentId: string): Promise<boolean> {
    const item = await this.watchlistRepository.findOne({
      where: { profileId, contentId },
    });
    return !!item;
  }

  // ── Watch History ──────────────────────────────────────
  async getWatchHistory(profileId: string, page = 1, limit = 20) {
    const [data, total] = await this.watchHistoryRepository.findAndCount({
      where: { profileId },
      order: { lastWatchedAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });

    const enriched = await Promise.all(
      data.map(async (item) => {
        try {
          const content = await this.contentService.findOne(item.contentId);
          return { ...item, content };
        } catch {
          return item;
        }
      }),
    );

    return {
      data: enriched,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async getContinueWatching(profileId: string, limit = 10) {
    return this.watchHistoryRepository.find({
      where: { profileId, isCompleted: false },
      order: { lastWatchedAt: 'DESC' },
      take: limit,
    });
  }

  async updateWatchProgress(profileId: string, dto: UpdateWatchProgressDto): Promise<WatchHistory> {
    let record = await this.watchHistoryRepository.findOne({
      where: {
        profileId,
        contentId: dto.contentId,
        ...(dto.episodeId ? { episodeId: dto.episodeId } : {}),
      },
    });

    const progressPercentage =
      dto.totalDuration > 0 ? Math.min(100, (dto.watchedDuration / dto.totalDuration) * 100) : 0;

    if (record) {
      record.watchedDuration = dto.watchedDuration;
      record.totalDuration = dto.totalDuration;
      record.progressPercentage = progressPercentage;
      record.isCompleted = progressPercentage >= 90;
      record.lastWatchedAt = new Date();
      record.metadata = dto.metadata;
    } else {
      record = this.watchHistoryRepository.create({
        profileId,
        contentId: dto.contentId,
        episodeId: dto.episodeId,
        watchedDuration: dto.watchedDuration,
        totalDuration: dto.totalDuration,
        progressPercentage,
        isCompleted: progressPercentage >= 90,
        lastWatchedAt: new Date(),
        metadata: dto.metadata,
      });
    }

    await this.contentService.incrementViewCount(dto.contentId);
    return this.watchHistoryRepository.save(record);
  }

  async getProgress(profileId: string, contentId: string, episodeId?: string) {
    const where: any = { profileId, contentId };
    if (episodeId) where.episodeId = episodeId;

    const record = await this.watchHistoryRepository.findOne({ where });
    if (!record) return { watchedDuration: 0, progressPercentage: 0, isCompleted: false };

    return {
      watchedDuration: record.watchedDuration,
      progressPercentage: record.progressPercentage,
      isCompleted: record.isCompleted,
    };
  }

  async clearHistory(profileId: string): Promise<void> {
    await this.watchHistoryRepository.delete({ profileId });
  }

  // Used by recommendations engine
  async getWatchedContentIds(profileId: string): Promise<string[]> {
    const records = await this.watchHistoryRepository.find({
      where: { profileId },
      select: ['contentId'],
    });
    return [...new Set(records.map((r) => r.contentId))];
  }
}
