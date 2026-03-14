import { IsString, IsNumber, IsOptional, Min, IsObject } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateWatchProgressDto {
  @ApiProperty()
  @IsString()
  contentId: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  episodeId?: string;

  @ApiProperty({ example: 3600, description: 'Seconds watched so far' })
  @IsNumber()
  @Min(0)
  watchedDuration: number;

  @ApiProperty({ example: 7200, description: 'Total content duration in seconds' })
  @IsNumber()
  @Min(0)
  totalDuration: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsObject()
  metadata?: {
    quality?: string;
    language?: string;
    subtitle?: string;
    device?: string;
  };
}
