import { IsNumber, IsArray, ValidateNested, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { Type } from 'class-transformer';
import { LogEntryDto } from './LogEntryDto';

export class BatchLogDto {
    @IsNumber()
    @IsOptional()
    sessionId?: number;

    // Device info for auto-creating session
    @IsString()
    @IsOptional()
    deviceKey?: string;

    @IsString()
    @IsOptional()
    appVersion?: string;

    @IsString()
    @IsOptional()
    buildNumber?: string;

    @IsString()
    @IsOptional()
    platform?: string;

    @IsArray()
    @IsNotEmpty()
    @ValidateNested({ each: true })
    @Type(() => LogEntryDto)
    logs: LogEntryDto[];
}
