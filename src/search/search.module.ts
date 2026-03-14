import { Module } from '@nestjs/common';
import { SearchController } from './search.controller';
import { SearchService } from './search.service';
import { ContentModule } from '../content/content.module';
import { CategoriesModule } from '../categories/categories.module';

@Module({
  imports: [ContentModule, CategoriesModule],
  controllers: [SearchController],
  providers: [SearchService],
  exports: [SearchService],
})
export class SearchModule {}
