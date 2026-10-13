import { LocalValues } from '../local/LocalValues';
import { KmpPersistenceService } from './KmpPersistenceService';

/** Owns native credentials and delegates all mutation scheduling to the KMP database. */
export class KmpAutomaticSyncConfigurator {
  private static instance: KmpAutomaticSyncConfigurator;
  private configuredSignature: string = '';

  private constructor() {}

  public static getInstance(): KmpAutomaticSyncConfigurator {
    if (!KmpAutomaticSyncConfigurator.instance) {
      KmpAutomaticSyncConfigurator.instance = new KmpAutomaticSyncConfigurator();
    }
    return KmpAutomaticSyncConfigurator.instance;
  }

  public configure(): void {
    const values: LocalValues = LocalValues.getInstance();
    const persistence: KmpPersistenceService = KmpPersistenceService.getInstance();
    const shouldEnable: boolean = values.getCloudSyncEnable() &&
      !values.getBasicMode() && values.getSyncMode() === 'webdav';
    const baseUrl: string = shouldEnable ? values.getWebDavUrl() : '';
    const username: string = values.getWebDavAuth().user;
    const password: string = values.getWebDavAuth().pass;
    const signature: string = baseUrl + '\u0000' + username + '\u0000' + password;
    if (signature === this.configuredSignature) return;
    persistence.configureAutomaticWebDavSync(baseUrl, username, password);
    this.configuredSignature = signature;
  }
}
