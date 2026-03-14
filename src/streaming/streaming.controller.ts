import { Controller, Get, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { StreamingService, StreamQuality } from './streaming.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('streaming')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
@Controller('streaming')
export class StreamingController {
  constructor(private readonly streamingService: StreamingService) {}

  @Get(':contentId/url')
  @ApiOperation({
    summary: 'Get signed streaming URL for a movie or episode',
    description:
      'Returns the CDN-signed video URL, available qualities, subtitles and audio tracks.',
  })
  getStreamUrl(
    @Param('contentId') contentId: string,
    @Query('quality') quality: StreamQuality,
    @Query('episodeId') episodeId?: string,
  ) {
    return this.streamingService.getStreamUrl(contentId, quality, episodeId);
  }

  @Get(':contentId/manifest')
  @ApiOperation({ summary: 'Get HLS/DASH manifest URL for adaptive streaming' })
  getManifest(@Param('contentId') contentId: string, @Query('episodeId') episodeId?: string) {
    return this.streamingService.getManifest(contentId, episodeId);
  }
}
