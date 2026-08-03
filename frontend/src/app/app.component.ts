import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';

import { environment } from '../environments/environment';
import { SupabaseService } from './supabase.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
})
export class AppComponent {
  private readonly supabase = inject(SupabaseService);

  readonly title = 'Revolution';
  readonly items = signal<unknown[]>([]);
  readonly error = signal<string | null>(null);
  readonly loading = signal(false);

  async loadItems(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.items.set(await this.supabase.getItems());
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'Failed to load items.',
      );
    } finally {
      this.loading.set(false);
    }
  }

  protected readonly configured =
    !environment.supabaseUrl.includes('your-project-ref');
}
