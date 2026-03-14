import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { RecommendationsService } from './recommendations.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('recommendations')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
@Controller('recommendations')
export class RecommendationsController {
  constructor(private readonly recommendationsService: RecommendationsService) {}

  @Get('profiles/:profileId/home')
  @ApiOperation({
    summary: 'Get personalized home page rows for a profile',
    description:
      'Returns content rows: continue watching, for you, based on history, trending, new, originals and genre rows.',
  })
  getPersonalizedHome(@Param('profileId') profileId: string) {
    return this.recommendationsService.getPersonalizedHomePage(profileId);
  }

  @Get('content/:contentId/similar')
  @ApiOperation({ summary: 'Get content similar to a given title' })
  getSimilar(@Param('contentId') contentId: string, @Query('limit') limit: number) {
    return this.recommendationsService.getSimilarContent(contentId, limit);
  }
}
