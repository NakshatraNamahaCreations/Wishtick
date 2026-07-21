import {
  type CallHandler,
  type ExecutionContext,
  Injectable,
  type NestInterceptor,
} from '@nestjs/common';
import type { Request } from 'express';
import { map, type Observable } from 'rxjs';

export interface ApiResponse<T> {
  success: true;
  data: T;
  requestId?: string;
  timestamp: string;
}

/**
 * Wraps every successful response so clients see one shape for success and one
 * for failure. Paginated endpoints return `{items, nextCursor}` as their `data`.
 */
@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, ApiResponse<T>> {
  intercept(context: ExecutionContext, next: CallHandler<T>): Observable<ApiResponse<T>> {
    const req = context.switchToHttp().getRequest<Request>();
    return next.handle().pipe(
      map((data) => ({
        success: true as const,
        data,
        requestId: req.id as string | undefined,
        timestamp: new Date().toISOString(),
      })),
    );
  }
}
