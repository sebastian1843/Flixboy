import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WatchlistController } from './watchlist.controller';
import { WatchlistService } from './watchlist.service';
import { Watchlist } from './entities/watchlist.entity';
import { WatchHistory } from './entities/watch-history.entity';
import { ContentModule } from '../content/content.module';

@Module({
  imports: [TypeOrmModule.forFeature([Watchlist, WatchHistory]), ContentModule],
  controllers: [WatchlistController],
  providers: [WatchlistService],
  exports: [WatchlistService, TypeOrmModule],
})
export class WatchlistModule {}
