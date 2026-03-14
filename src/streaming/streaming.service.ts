import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ContentService } from '../content/content.service';
import { WatchlistService } from '../watchlist/watchlist.service';
import { ContentType } from '../content/entities/content.entity';

export enum StreamQuality {
  AUTO = 'auto',
  SD = 'sd', // 480p
  HD = 'hd', // 720p / 1080p
  UHD = '4k', // 2160p
}

@Injectable()
export class StreamingService {
  constructor(
    private contentService: ContentService,
    private configService: ConfigService,
  ) {}

  /**
   * Resolve the signed streaming URL for a movie or a specific episode.
   * Returns the URL and metadata needed by the player.
   */
  async getStreamUrl(
    contentId: string,
    quality: StreamQuality = StreamQuality.AUTO,
    episodeId?: string,
  ) {
    const content = await this.contentService.findOne(contentId);

    if (content.type === ContentType.SERIES && !episodeId) {
      throw new ForbiddenException('episodeId is required for series');
    }

    let videoUrl: string;
    let durationMinutes: number;

    if (episodeId) {
      const episode = await this.contentService.getEpisode(episodeId);
      videoUrl = this.selectQualityUrl(
        {
          sd: episode.videoUrlSd,
          hd: episode.videoUrlHd,
          uhd: episode.videoUrl4k,
          default: episode.videoUrl,
        },
        quality,
      );
      durationMinutes = episode.durationMinutes;
    } else {
      videoUrl = this.selectQualityUrl(
        {
          sd: content.videoUrlSd,
          hd: content.videoUrlHd,
          uhd: content.videoUrl4k,
          default: content.videoUrl,
        },
        quality,
      );
      durationMinutes = content.durationMinutes;
    }

    if (!videoUrl) throw new NotFoundException('Video not available in requested quality');

    // Sign the URL (append expiry token for CDN-signed URLs)
    const signedUrl = this.signUrl(videoUrl);

    return {
      url: signedUrl,
      quality: this.resolveQualityLabel(quality, videoUrl),
      durationMinutes,
      contentId,
      episodeId: episodeId ?? null,
      availableQualities: this.getAvailableQualities(content, episodeId),
      subtitles: content.subtitles ?? [],
      audioLanguages: content.languages ?? [],
    };
  }

  /**
   * Returns manifest info for adaptive streaming clients (HLS/DASH).
   * The actual manifest file lives on the CDN; we just return its signed URL.
   */
  async getManifest(contentId: string, episodeId?: string) {
    const { url } = await this.getStreamUrl(contentId, StreamQuality.AUTO, episodeId);
    return { manifestUrl: url };
  }

  // ── Private helpers ────────────────────────────────────

  private selectQualityUrl(
    urls: { sd?: string; hd?: string; uhd?: string; default?: string },
    quality: StreamQuality,
  ): string {
    switch (quality) {
      case StreamQuality.UHD:
        return urls.uhd || urls.hd || urls.sd || urls.default;
      case StreamQuality.HD:
        return urls.hd || urls.sd || urls.default;
      case StreamQuality.SD:
        return urls.sd || urls.default;
      default: // AUTO — prefer best available
        return urls.uhd || urls.hd || urls.sd || urls.default;
    }
  }

  private resolveQualityLabel(requested: StreamQuality, resolvedUrl: string): string {
    if (resolvedUrl?.includes('4k') || resolvedUrl?.includes('2160')) return '4K';
    if (resolvedUrl?.includes('1080')) return '1080p';
    if (resolvedUrl?.includes('720')) return '720p';
    if (resolvedUrl?.includes('480')) return '480p';
    return requested === StreamQuality.AUTO ? 'Auto' : requested.toUpperCase();
  }

  /**
   * Sign a CDN URL with a short-lived token.
   * Replace this implementation with your CDN's signing logic
   * (e.g., AWS CloudFront signed URLs, Bunny.net token auth, etc.)
   */
  private signUrl(url: string): string {
    const cdnBase = this.configService.get('AWS_CLOUDFRONT_URL');
    if (!cdnBase || !url) return url;

    // Example: append a simple expiry timestamp.
    // In production use aws-sdk CloudFront.getSignedUrl() or equivalent.
    const expiresAt = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    const separator = url.includes('?') ? '&' : '?';
    return `${url}${separator}Expires=${expiresAt}`;
  }

  private getAvailableQualities(content: any, episodeId?: string): string[] {
    const qualities: string[] = [];
    const source = episodeId
      ? content.seasons?.flatMap((s) => s.episodes)?.find((e) => e.id === episodeId)
      : content;

    if (!source) return ['Auto'];
    if (source.videoUrl4k) qualities.push('4K');
    if (source.videoUrlHd) qualities.push('1080p', '720p');
    if (source.videoUrlSd) qualities.push('480p');
    if (qualities.length === 0) qualities.push('Auto');
    return qualities;
  }
}
