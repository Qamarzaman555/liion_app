import { IsString, IsNotEmpty, IsOptional, IsDateString } from 'class-validator';

export class LogEntryDto {
  @IsDateString()
  @IsOptional()
  ts?: string;

  @IsString()
  @IsNotEmpty()
  level: string;

  @IsString()
  @IsNotEmpty()
  message: string;
}

