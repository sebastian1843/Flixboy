import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ContentController } from './content.controller';
import { ContentService } from './content.service';
import { Content } from './entities/content.entity';
import { Season } from './entities/season.entity';
import { Episode } from './entities/episode.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Content, Season, Episode])],
  controllers: [ContentController],
  providers: [ContentService],
  exports: [ContentService, TypeOrmModule],
})
export class ContentModule {}
