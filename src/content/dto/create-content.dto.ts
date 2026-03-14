import {
  IsString,
  IsOptional,
  IsEnum,
  IsBoolean,
  IsArray,
  IsNumber,
  Min,
  Max,
  IsUrl,
  MaxLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ContentType, AgeClassification } from '../entities/content.entity';

export class CreateContentDto {
  @ApiProperty({ example: 'Inception' })
  @IsString()
  @MaxLength(200)
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  originalTitle?: string;

  @ApiProperty()
  @IsString()
  synopsis: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  shortSynopsis?: string;

  @ApiProperty({ enum: ContentType })
  @IsEnum(ContentType)
  type: ContentType;

  @ApiProperty({ example: 2010 })
  @IsNumber()
  @Min(1888)
  releaseYear: number;

  @ApiPropertyOptional({ example: 148 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  durationMinutes?: number;

  @ApiPropertyOptional({ enum: AgeClassification })
  @IsOptional()
  @IsEnum(AgeClassification)
  ageClassification?: AgeClassification;

  @ApiPropertyOptional({ example: ['Leonardo DiCaprio', 'Ellen Page'] })
  @IsOptional()
  @IsArray()
  cast?: string[];

  @ApiPropertyOptional({ example: ['Christopher Nolan'] })
  @IsOptional()
  @IsArray()
  directors?: string[];

  @ApiPropertyOptional({ example: ['es', 'en', 'fr'] })
  @IsOptional()
  @IsArray()
  languages?: string[];

  @ApiPropertyOptional({ example: ['es', 'en'] })
  @IsOptional()
  @IsArray()
  subtitles?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  thumbnailUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  bannerUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  trailerUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  videoUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  videoUrl4k?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  videoUrlHd?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  videoUrlSd?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isOriginal?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isTrending?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isFeatured?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isNew?: boolean;

  @ApiPropertyOptional({ example: ['thriller', 'mind-bending'] })
  @IsOptional()
  @IsArray()
  tags?: string[];

  @ApiPropertyOptional({ example: 'USA' })
  @IsOptional()
  @IsString()
  country?: string;
}
