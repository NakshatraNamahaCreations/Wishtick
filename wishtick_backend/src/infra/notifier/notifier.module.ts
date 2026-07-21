import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppConfig } from 'src/config/configuration';
import { ConsoleMailerAdapter } from './adapters/console-mailer.adapter';
import { ConsoleSmsAdapter } from './adapters/console-sms.adapter';
import { HttpSmsAdapter } from './adapters/http-sms.adapter';
import { SesMailerAdapter } from './adapters/ses-mailer.adapter';
import { MAILER, type IMailer } from './mailer.port';
import { SMS_SENDER, type ISmsSender } from './sms.port';

/**
 * Driver selection is config-driven, as the port comments promised: adding a
 * provider is adding a `case`, and no consumer of MAILER / SMS_SENDER changes.
 * Console is the dev default; SES and the HTTP SMS gateway are the real drivers.
 */
@Global()
@Module({
  providers: [
    ConsoleMailerAdapter,
    SesMailerAdapter,
    ConsoleSmsAdapter,
    HttpSmsAdapter,
    {
      provide: MAILER,
      inject: [ConfigService, ConsoleMailerAdapter, SesMailerAdapter],
      useFactory: (
        config: ConfigService<AppConfig, true>,
        console: ConsoleMailerAdapter,
        ses: SesMailerAdapter,
      ): IMailer =>
        config.get('delivery.mailerDriver', { infer: true }) === 'ses' ? ses : console,
    },
    {
      provide: SMS_SENDER,
      inject: [ConfigService, ConsoleSmsAdapter, HttpSmsAdapter],
      useFactory: (
        config: ConfigService<AppConfig, true>,
        console: ConsoleSmsAdapter,
        http: HttpSmsAdapter,
      ): ISmsSender =>
        config.get('delivery.smsDriver', { infer: true }) === 'http' ? http : console,
    },
  ],
  exports: [MAILER, SMS_SENDER],
})
export class NotifierModule {}
