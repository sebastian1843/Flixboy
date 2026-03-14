import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RecommendationsController } from './recommendations.controller';
import { RecommendationsService } from './recommendations.service';
import { ContentModule } from '../content/content.module';
import { ProfilesModule } from '../profiles/profiles.module';
import { WatchlistModule } from '../watchlist/watchlist.module';
import { Content } from '../content/entities/content.entity';
import { WatchHistory } from '../watchlist/entities/watch-history.entity';
import { Profile } from '../profiles/entities/profile.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Content, WatchHistory, Profile]),
    ContentModule,
    ProfilesModule,
    WatchlistModule,
  ],
  controllers: [RecommendationsController],
  providers: [RecommendationsService],
  exports: [RecommendationsService],
})
export class RecommendationsModule {}
