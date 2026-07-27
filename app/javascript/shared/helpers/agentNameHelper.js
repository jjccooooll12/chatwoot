// Agents are always shown as "First L." (e.g. "Libero Cole" -> "Libero C."),
// never their full last name, across every ticket-facing surface (message
// thread, ticket list, properties panel, merge panel, ...). Non-name strings
// (e.g. an "Unassigned" placeholder) pass through unchanged since they have
// no second word to abbreviate.
export const shortenAgentName = name => {
  if (!name) return name;
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length < 2) return name;
  const lastInitial = parts[parts.length - 1].charAt(0).toUpperCase();
  return `${parts[0]} ${lastInitial}.`;
};
