import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Query,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
  Patch,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { WatchlistService } from './watchlist.service';
import { UpdateWatchProgressDto } from './dto/update-watch-progress.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('watchlist')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
@Controller('profiles/:profileId')
export class WatchlistController {
  constructor(private readonly watchlistService: WatchlistService) {}

  // ── Watchlist ──────────────────────────────────────────
  @Get('watchlist')
  @ApiOperation({ summary: 'Get profile watchlist (My List)' })
  getWatchlist(
    @Param('profileId') profileId: string,
    @Query('page') page: number,
    @Query('limit') limit: number,
  ) {
    return this.watchlistService.getWatchlist(profileId, page, limit);
  }

  @Post('watchlist/:contentId')
  @ApiOperation({ summary: 'Add content to watchlist' })
  addToWatchlist(@Param('profileId') profileId: string, @Param('contentId') contentId: string) {
    return this.watchlistService.addToWatchlist(profileId, contentId);
  }

  @Delete('watchlist/:contentId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Remove content from watchlist' })
  removeFromWatchlist(
    @Param('profileId') profileId: string,
    @Param('contentId') contentId: string,
  ) {
    return this.watchlistService.removeFromWatchlist(profileId, contentId);
  }

  @Get('watchlist/:contentId/status')
  @ApiOperation({ summary: 'Check if content is in watchlist' })
  checkWatchlist(@Param('profileId') profileId: string, @Param('contentId') contentId: string) {
    return this.watchlistService.isInWatchlist(profileId, contentId);
  }

  // ── Watch History ──────────────────────────────────────
  @Get('history')
  @ApiOperation({ summary: 'Get watch history for a profile' })
  getHistory(
    @Param('profileId') profileId: string,
    @Query('page') page: number,
    @Query('limit') limit: number,
  ) {
    return this.watchlistService.getWatchHistory(profileId, page, limit);
  }

  @Get('continue-watching')
  @ApiOperation({ summary: 'Get content currently in progress (continue watching row)' })
  getContinueWatching(@Param('profileId') profileId: string, @Query('limit') limit: number) {
    return this.watchlistService.getContinueWatching(profileId, limit);
  }

  @Post('progress')
  @ApiOperation({ summary: 'Update watch progress (called periodically during playback)' })
  updateProgress(@Param('profileId') profileId: string, @Body() dto: UpdateWatchProgressDto) {
    return this.watchlistService.updateWatchProgress(profileId, dto);
  }

  @Get('progress/:contentId')
  @ApiOperation({ summary: 'Get watch progress for a specific content' })
  getProgress(
    @Param('profileId') profileId: string,
    @Param('contentId') contentId: string,
    @Query('episodeId') episodeId?: string,
  ) {
    return this.watchlistService.getProgress(profileId, contentId, episodeId);
  }

  @Delete('history')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Clear all watch history for a profile' })
  clearHistory(@Param('profileId') profileId: string) {
    return this.watchlistService.clearHistory(profileId);
  }
}
