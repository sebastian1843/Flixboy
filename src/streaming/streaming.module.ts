import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { StreamingController } from './streaming.controller';
import { StreamingService } from './streaming.service';
import { ContentModule } from '../content/content.module';
import { WatchlistModule } from '../watchlist/watchlist.module';

@Module({
  imports: [ContentModule, WatchlistModule],
  controllers: [StreamingController],
  providers: [StreamingService],
  exports: [StreamingService],
})
export class StreamingModule {}
