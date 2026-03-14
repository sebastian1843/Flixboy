import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ProfilesService } from './profiles.service';
import { CreateProfileDto } from './dto/create-profile.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('profiles')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
@Controller('profiles')
export class ProfilesController {
  constructor(private readonly profilesService: ProfilesService) {}

  @Get()
  @ApiOperation({ summary: 'List all profiles for current user (max 4)' })
  findAll(@Req() req) {
    return this.profilesService.findAllByUser(req.user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a specific profile' })
  findOne(@Param('id') id: string, @Req() req) {
    return this.profilesService.findOne(id, req.user.id);
  }

  @Post()
  @ApiOperation({ summary: 'Create a new profile (max 4 per account)' })
  create(@Req() req, @Body() createProfileDto: CreateProfileDto) {
    return this.profilesService.create(req.user.id, createProfileDto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a profile' })
  update(@Param('id') id: string, @Req() req, @Body() updateProfileDto: UpdateProfileDto) {
    return this.profilesService.update(id, req.user.id, updateProfileDto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a profile' })
  remove(@Param('id') id: string, @Req() req) {
    return this.profilesService.remove(id, req.user.id);
  }

  @Post(':id/verify-pin')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify profile PIN' })
  verifyPin(@Param('id') id: string, @Req() req, @Body('pin') pin: string) {
    return this.profilesService.verifyPin(id, req.user.id, pin);
  }
}
