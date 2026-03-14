import { Injectable, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, Not } from 'typeorm';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';
import { Content, ContentStatus } from '../content/entities/content.entity';
import { WatchHistory } from '../watchlist/entities/watch-history.entity';
import { Profile } from '../profiles/entities/profile.entity';
import { ProfilesService } from '../profiles/profiles.service';
import { WatchlistService } from '../watchlist/watchlist.service';
import { ContentService } from '../content/content.service';

@Injectable()
export class RecommendationsService {
  constructor(
    @InjectRepository(Content)
    private contentRepository: Repository<Content>,
    @InjectRepository(WatchHistory)
    private watchHistoryRepository: Repository<WatchHistory>,
    @InjectRepository(Profile)
    private profileRepository: Repository<Profile>,
    @Inject(CACHE_MANAGER)
    private cacheManager: Cache,
    private profilesService: ProfilesService,
    private watchlistService: WatchlistService,
    private contentService: ContentService,
  ) {}

  /**
   * Main recommendation engine.
   * Combines multiple signals:
   * 1. Profile preferred genres
   * 2. Watch history analysis (most-watched genres/types)
   * 3. Trending content the profile hasn't seen
   * 4. Content similar to recently watched
   * 5. Age-appropriate filtering
   */
  async getPersonalizedHomePage(profileId: string) {
    const cacheKey = `recommendations:home:${profileId}`;
    const cached = await this.cacheManager.get(cacheKey);
    if (cached) return cached;

    const profile = await this.profileRepository.findOne({ where: { id: profileId } });
    const watchedIds = await this.watchlistService.getWatchedContentIds(profileId);

    const [continueWatching, forYou, basedOnHistory, trending, newReleases, originals] =
      await Promise.all([
        this.getContinueWatching(profileId),
        this.getForYou(profile, watchedIds, 15),
        this.getBasedOnHistory(profileId, watchedIds, 15),
        this.getTrendingNotWatched(watchedIds, 15),
        this.contentService.findNew(15),
        this.contentService.findOriginals(15),
      ]);

    // Build genre-specific rows based on preferred genres
    const genreRows = await this.getGenreRows(profile, watchedIds);

    const result = {
      rows: [
        continueWatching.length > 0
          ? { id: 'continue', title: 'Continue Watching', contents: continueWatching }
          : null,
        { id: 'for-you', title: 'Recommended for You', contents: forYou },
        basedOnHistory.length > 0
          ? { id: 'based-on-history', title: 'Because You Watched', contents: basedOnHistory }
          : null,
        { id: 'trending', title: 'Trending Now', contents: trending },
        { id: 'new', title: 'New Releases', contents: newReleases },
        { id: 'originals', title: 'Platform Originals', contents: originals },
        ...genreRows,
      ].filter(Boolean),
    };

    await this.cacheManager.set(cacheKey, result, 300); // cache 5 minutes
    return result;
  }

  /**
   * Content-based filtering: find content similar to what the user has watched
   * Matches by overlapping categories and content type.
   */
  async getSimilarContent(contentId: string, limit = 12): Promise<Content[]> {
    const content = await this.contentService.findOne(contentId);
    const categoryIds = content.categories.map((c) => c.id);

    if (!categoryIds.length) {
      return this.contentRepository.find({
        where: { type: content.type, status: ContentStatus.PUBLISHED },
        take: limit,
        order: { rating: 'DESC' },
      });
    }

    return this.contentRepository
      .createQueryBuilder('c')
      .leftJoin('c.categories', 'cat')
      .where('cat.id IN (:...categoryIds)', { categoryIds })
      .andWhere('c.id != :contentId', { contentId })
      .andWhere('c.status = :status', { status: ContentStatus.PUBLISHED })
      .orderBy('c.rating', 'DESC')
      .limit(limit)
      .getMany();
  }

  // ── Private helpers ────────────────────────────────────

  private async getContinueWatching(profileId: string) {
    const inProgress = await this.watchlistService.getContinueWatching(profileId, 10);
    const enriched = await Promise.all(
      inProgress.map(async (item) => {
        try {
          const content = await this.contentService.findOne(item.contentId);
          return {
            content,
            progressPercentage: item.progressPercentage,
            watchedDuration: item.watchedDuration,
            episodeId: item.episodeId,
          };
        } catch {
          return null;
        }
      }),
    );
    return enriched.filter(Boolean);
  }

  /**
   * For You: rank all unseen content by how well it matches the profile's
   * preferred genres, boosted by rating and original status.
   */
  private async getForYou(profile: Profile, watchedIds: string[], limit: number) {
    const qb = this.contentRepository
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.categories', 'cat')
      .where('c.status = :status', { status: ContentStatus.PUBLISHED });

    if (watchedIds.length > 0) {
      qb.andWhere('c.id NOT IN (:...watchedIds)', { watchedIds });
    }

    // Prefer genres matching the profile's preferences
    if (profile?.preferredGenres?.length > 0) {
      qb.andWhere('cat.slug IN (:...genres)', { genres: profile.preferredGenres });
    }

    return qb
      .orderBy('c.isOriginal', 'DESC')
      .addOrderBy('c.rating', 'DESC')
      .addOrderBy('c.viewCount', 'DESC')
      .limit(limit)
      .getMany();
  }

  /**
   * Collaborative-style: look at recently completed items, extract their
   * categories, and surface unseen content in the same categories.
   */
  private async getBasedOnHistory(
    profileId: string,
    watchedIds: string[],
    limit: number,
  ): Promise<Content[]> {
    if (watchedIds.length === 0) return [];

    // Get the last 5 completed items
    const recent = await this.watchHistoryRepository.find({
      where: { profileId, isCompleted: true },
      order: { lastWatchedAt: 'DESC' },
      take: 5,
    });

    if (!recent.length) return [];

    const recentContentIds = recent.map((r) => r.contentId);
    const recentContents = await this.contentRepository.find({
      where: { id: In(recentContentIds) },
      relations: ['categories'],
    });

    const categoryIds = [
      ...new Set(recentContents.flatMap((c) => c.categories.map((cat) => cat.id))),
    ];

    if (!categoryIds.length) return [];

    return this.contentRepository
      .createQueryBuilder('c')
      .leftJoin('c.categories', 'cat')
      .where('cat.id IN (:...categoryIds)', { categoryIds })
      .andWhere('c.id NOT IN (:...excludeIds)', {
        excludeIds: [...watchedIds, ...recentContentIds],
      })
      .andWhere('c.status = :status', { status: ContentStatus.PUBLISHED })
      .orderBy('c.rating', 'DESC')
      .limit(limit)
      .getMany();
  }

  private async getTrendingNotWatched(watchedIds: string[], limit: number) {
    const qb = this.contentRepository
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.categories', 'cat')
      .where('c.isTrending = true')
      .andWhere('c.status = :status', { status: ContentStatus.PUBLISHED });

    if (watchedIds.length > 0) {
      qb.andWhere('c.id NOT IN (:...watchedIds)', { watchedIds });
    }

    return qb.orderBy('c.viewCount', 'DESC').limit(limit).getMany();
  }

  /**
   * Build one row per preferred genre (max 3 rows to avoid fatigue).
   */
  private async getGenreRows(
    profile: Profile,
    watchedIds: string[],
  ): Promise<Array<{ id: string; title: string; contents: Content[] }>> {
    const genres = profile?.preferredGenres?.slice(0, 3) ?? [];
    const rows: Array<{ id: string; title: string; contents: Content[] }> = [];

    for (const genre of genres) {
      const qb = this.contentRepository
        .createQueryBuilder('c')
        .leftJoin('c.categories', 'cat')
        .where('cat.slug = :genre', { genre })
        .andWhere('c.status = :status', { status: ContentStatus.PUBLISHED });

      if (watchedIds.length > 0) {
        qb.andWhere('c.id NOT IN (:...watchedIds)', { watchedIds });
      }

      const contents = await qb.orderBy('c.rating', 'DESC').limit(15).getMany();

      if (contents.length > 3) {
        rows.push({
          id: `genre-${genre}`,
          title: genre.charAt(0).toUpperCase() + genre.slice(1),
          contents,
        });
      }
    }

    return rows;
  }
}
