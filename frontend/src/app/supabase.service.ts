import { Injectable } from '@angular/core';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

import { environment } from '../environments/environment';

@Injectable({ providedIn: 'root' })
export class SupabaseService {
  readonly client: SupabaseClient;

  constructor() {
    this.client = createClient(
      environment.supabaseUrl,
      environment.supabaseKey,
    );
  }

  /** Example: read all rows from an `items` table. */
  async getItems(): Promise<unknown[]> {
    const { data, error } = await this.client.from('items').select('*');
    if (error) {
      throw error;
    }
    return data ?? [];
  }
}
