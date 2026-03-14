import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { SearchService } from './search.service';
import { SearchQueryDto } from './dto/search-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('search')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get()
  @ApiOperation({ summary: 'Full-text search across title, synopsis and tags' })
  search(@Query() query: SearchQueryDto) {
    return this.searchService.search(query);
  }

  @Get('autocomplete')
  @ApiOperation({ summary: 'Autocomplete suggestions for search bar' })
  autocomplete(@Query('q') q: string, @Query('limit') limit: number) {
    return this.searchService.autocomplete(q, limit);
  }

  @Get('popular')
  @ApiOperation({ summary: 'Get popular search terms (trending titles)' })
  getPopular(@Query('limit') limit: number) {
    return this.searchService.getPopularSearches(limit);
  }
}
