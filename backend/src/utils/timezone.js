/**
 * Get current date/time in Pakistani Standard Time (UTC+5)
 * Returns a Date object that represents Pakistani time directly
 * This time will be stored in the database as-is (representing Pakistani time)
 * @returns {Date} Date object representing current Pakistani time
 */
export function getKarachiTime() {
  const now = new Date();
  // Get current UTC time
  const utcTime = now.getTime();
  // Pakistani Standard Time is UTC+5, so add 5 hours to get Pakistani time
  // This creates a Date object that represents Pakistani time
  // When stored in PostgreSQL, it will be stored as Pakistani time (not UTC)
  const pakistaniOffsetMs = 5 * 60 * 60 * 1000; // 5 hours in milliseconds
  return new Date(utcTime + pakistaniOffsetMs);
}

/**
 * Parse a date string from Android (which sends timestamps in Pakistani time without offset)
 * Android sends: "2025-12-03T14:30:45.123" (representing 14:30 in Pakistan)
 * We parse it as UTC (by adding Z) so it represents that exact time
 * When stored and read back, it will show the same time (Pakistani time)
 * @param {string} dateString - ISO date string without timezone (e.g., "2025-12-03T14:30:45.123")
 * @returns {Date} Date object representing Pakistani time
 */
export function parseToKarachiTime(dateString) {
  if (!dateString) {
    return getKarachiTime();
  }

  // Android sends timestamp without timezone offset (e.g., "2025-12-03T14:30:45.123")
  // This represents Pakistani time. To store it correctly:
  // 1. Parse it as UTC by adding 'Z' - this treats "14:30" as 14:30 UTC
  // 2. Store it in database - PostgreSQL will store as 14:30 UTC
  // 3. When reading back, format using UTC methods - will show 14:30 (Pakistani time)
  // This way, the time stored matches what Android sent (Pakistani time)

  // Parse as UTC (treats the time as-is)
  const parsedDate = new Date(dateString + 'Z');

  // If parsing fails, try without Z
  if (isNaN(parsedDate.getTime())) {
    return new Date(dateString + 'Z'); // Force UTC parsing
  }

  return parsedDate;
}

/**
 * Format a Date object to ISO string in Pakistani time (without timezone offset)
 * @param {Date} date - Date object (stored as Pakistani time in database)
 * @returns {string} ISO string without timezone (e.g., "2025-12-03T14:30:45.123")
 */
export function formatKarachiTime(date) {
  if (!date) {
    return formatKarachiTime(getKarachiTime());
  }

  // Date object represents Pakistani time
  // Format it as ISO string without timezone notation
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  const hours = String(date.getUTCHours()).padStart(2, '0');
  const minutes = String(date.getUTCMinutes()).padStart(2, '0');
  const seconds = String(date.getUTCSeconds()).padStart(2, '0');
  const milliseconds = String(date.getUTCMilliseconds()).padStart(3, '0');

  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}.${milliseconds}`;
}

