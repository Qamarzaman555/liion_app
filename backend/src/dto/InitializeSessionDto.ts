import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class InitializeSessionDto {
  @IsString()
  @IsNotEmpty()
  deviceKey: string;

  @IsString()
  @IsNotEmpty()
  appVersion: string;

  @IsString()
  @IsNotEmpty()
  buildNumber: string;

  @IsString()
  @IsOptional()
  platform?: string;
}

