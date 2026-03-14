import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags, ApiQuery } from '@nestjs/swagger';
import { ContentService } from './content.service';
import { CreateContentDto } from './dto/create-content.dto';
import { UpdateContentDto } from './dto/update-content.dto';
import { ContentQueryDto } from './dto/content-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('content')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
@Controller('content')
export class ContentController {
  constructor(private readonly contentService: ContentService) {}

  @Get()
  @ApiOperation({ summary: 'List all published content with filters and pagination' })
  findAll(@Query() query: ContentQueryDto) {
    return this.contentService.findAll(query);
  }

  @Get('home')
  @ApiOperation({ summary: 'Get home page rows (trending, new, originals, by type...)' })
  getHomePage() {
    return this.contentService.getHomePage();
  }

  @Get('trending')
  @ApiOperation({ summary: 'Get trending content' })
  getTrending(@Query('limit') limit: number) {
    return this.contentService.findTrending(limit);
  }

  @Get('new')
  @ApiOperation({ summary: 'Get new releases' })
  getNew(@Query('limit') limit: number) {
    return this.contentService.findNew(limit);
  }

  @Get('originals')
  @ApiOperation({ summary: 'Get platform originals' })
  getOriginals(@Query('limit') limit: number) {
    return this.contentService.findOriginals(limit);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get full content detail with cast, seasons, episodes' })
  findOne(@Param('id') id: string) {
    return this.contentService.findOne(id);
  }

  @Get(':id/seasons')
  @ApiOperation({ summary: 'Get all seasons of a series' })
  getSeasons(@Param('id') id: string) {
    return this.contentService.getSeasons(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create new content (admin)' })
  create(@Body() createContentDto: CreateContentDto) {
    return this.contentService.create(createContentDto);
  }

  @Post(':id/seasons')
  @ApiOperation({ summary: 'Add a season to a series (admin)' })
  createSeason(@Param('id') id: string, @Body() seasonData: any) {
    return this.contentService.createSeason(id, seasonData);
  }

  @Post('seasons/:seasonId/episodes')
  @ApiOperation({ summary: 'Add an episode to a season (admin)' })
  createEpisode(@Param('seasonId') seasonId: string, @Body() episodeData: any) {
    return this.contentService.createEpisode(seasonId, episodeData);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update content (admin)' })
  update(@Param('id') id: string, @Body() updateContentDto: UpdateContentDto) {
    return this.contentService.update(id, updateContentDto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete content (admin)' })
  remove(@Param('id') id: string) {
    return this.contentService.remove(id);
  }
}
