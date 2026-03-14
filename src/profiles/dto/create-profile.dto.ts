import {
  IsString,
  IsOptional,
  IsEnum,
  IsBoolean,
  IsArray,
  MaxLength,
  MinLength,
  IsHexColor,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { AgeRating } from '../entities/profile.entity';

export class CreateProfileDto {
  @ApiProperty({ example: 'Juan' })
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  name: string;

  @ApiPropertyOptional({ example: 'https://...' })
  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @ApiPropertyOptional({ example: '#E50914' })
  @IsOptional()
  @IsHexColor()
  avatarColor?: string;

  @ApiPropertyOptional({ enum: AgeRating, default: AgeRating.ALL })
  @IsOptional()
  @IsEnum(AgeRating)
  ageRating?: AgeRating;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isKidsProfile?: boolean;

  @ApiPropertyOptional({ example: '1234' })
  @IsOptional()
  @IsString()
  @MinLength(4)
  @MaxLength(6)
  pin?: string;

  @ApiPropertyOptional({ example: ['action', 'comedy'] })
  @IsOptional()
  @IsArray()
  preferredGenres?: string[];

  @ApiPropertyOptional({ example: ['es', 'en'] })
  @IsOptional()
  @IsArray()
  preferredLanguages?: string[];

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  autoPlayNext?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  autoPlayPreviews?: boolean;
}
