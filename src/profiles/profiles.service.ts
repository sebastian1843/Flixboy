import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Profile } from './entities/profile.entity';
import { CreateProfileDto } from './dto/create-profile.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

const MAX_PROFILES = 4;

@Injectable()
export class ProfilesService {
  constructor(
    @InjectRepository(Profile)
    private profilesRepository: Repository<Profile>,
  ) {}

  async findAllByUser(userId: string): Promise<Profile[]> {
    return this.profilesRepository.find({ where: { userId } });
  }

  async findOne(id: string, userId: string): Promise<Profile> {
    const profile = await this.profilesRepository.findOne({ where: { id } });
    if (!profile) throw new NotFoundException('Profile not found');
    if (profile.userId !== userId) throw new ForbiddenException('Access denied');
    return profile;
  }

  async create(userId: string, createProfileDto: CreateProfileDto): Promise<Profile> {
    const existingProfiles = await this.profilesRepository.count({ where: { userId } });
    if (existingProfiles >= MAX_PROFILES) {
      throw new BadRequestException(`Maximum of ${MAX_PROFILES} profiles allowed per account`);
    }

    const profile = this.profilesRepository.create({
      ...createProfileDto,
      userId,
    });

    return this.profilesRepository.save(profile);
  }

  async update(id: string, userId: string, updateProfileDto: UpdateProfileDto): Promise<Profile> {
    const profile = await this.findOne(id, userId);
    Object.assign(profile, updateProfileDto);
    return this.profilesRepository.save(profile);
  }

  async remove(id: string, userId: string): Promise<void> {
    const profile = await this.findOne(id, userId);
    await this.profilesRepository.remove(profile);
  }

  async verifyPin(id: string, userId: string, pin: string): Promise<boolean> {
    const profile = await this.findOne(id, userId);
    if (!profile.pin) return true;
    return profile.pin === pin;
  }
}
