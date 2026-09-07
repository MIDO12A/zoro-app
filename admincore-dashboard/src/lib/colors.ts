export function to6Hex(c: string): string {
  if (!c || typeof c !== 'string') return '#000000';
  const trimmed = c.trim().toLowerCase();
  if (trimmed === 'transparent' || trimmed === 'none' || trimmed === '') return '#000000';
  if (/^#[0-9a-f]{6}$/i.test(trimmed)) return trimmed;
  if (/^#[0-9a-f]{8}$/i.test(trimmed)) return '#' + trimmed.substring(3, 9);
  if (/^#[0-9a-f]{3}$/i.test(trimmed)) return '#' + trimmed[1] + trimmed[1] + trimmed[2] + trimmed[2] + trimmed[3] + trimmed[3];
  if (/^#[0-9a-f]{4}$/i.test(trimmed)) return '#' + trimmed[1] + trimmed[1] + trimmed[2] + trimmed[2] + trimmed[3] + trimmed[3];
  return '#000000';
}
