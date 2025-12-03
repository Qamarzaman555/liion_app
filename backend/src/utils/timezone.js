/**
 * Get current date/time in UTC
 * This will be stored in PostgreSQL as UTC (standard practice)
 * When displayed, it will be formatted to Pakistani time (UTC+5)
 * @returns {Date} Date object in UTC
 */
export function getKarachiTime() {
  // Return current UTC time
  // When formatted with formatKarachiTime(), it will show Pakistani time
  return new Date();
}

/**
 * Parse a date string from Android (which sends timestamps in UTC+5 format)
 * JavaScript Date automatically converts timezone-aware strings to UTC
 * @param {string} dateString - ISO date string (e.g., "2025-12-03T14:30:45.123+05:00")
 * @returns {Date} Date object in UTC (ready to store in PostgreSQL)
 */
export function parseToKarachiTime(dateString) {
  if (!dateString) {
    return getKarachiTime();
  }
  
  // Parse the incoming date string
  // If Android sends "2025-12-03T14:30:45.123+05:00" (14:30 in Pakistan),
  // JavaScript Date will correctly parse it and convert to UTC (09:30 UTC)
  // This is correct - we store UTC in the database
  // When we format it back with formatKarachiTime(), it will show 14:30 again
  const parsedDate = new Date(dateString);
  return parsedDate;
}

/**
 * Format a Date object to ISO string in UTC+5 timezone (Pakistani Standard Time)
 * @param {Date} date - Date object (stored in UTC in database)
 * @returns {string} ISO string with UTC+5 offset (e.g., "2025-12-03T14:30:45.123+05:00")
 */
export function formatKarachiTime(date) {
  if (!date) {
    const karachiNow = getKarachiTime();
    return karachiNow.toISOString().replace('Z', '+05:00');
  }
  
  // Date object is in UTC (as stored in PostgreSQL)
  // Convert to Pakistani time by adding 5 hours
  const utcTime = date.getTime();
  const karachiOffset = 5 * 60 * 60 * 1000; // 5 hours in milliseconds
  const karachiTime = new Date(utcTime + karachiOffset);
  
  // Format as ISO string and replace Z with +05:00 to show Pakistani time
  return karachiTime.toISOString().replace('Z', '+05:00');
}

