// This file documents which TypeORM feature arrays are needed in
// RecommendationsModule so the injected repositories resolve correctly.
// Add the following to recommendations.module.ts imports if you see
// "No repository for WatchHistory / Profile" errors at startup:
//
//   TypeOrmModule.forFeature([Content, WatchHistory, Profile])
//
// Already handled by re-exporting TypeOrmModule from ContentModule,
// ProfilesModule, and WatchlistModule — but if you split modules further
// add the forFeature imports here.
export {};
