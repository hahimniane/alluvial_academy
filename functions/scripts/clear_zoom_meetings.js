const accountId = '-ntyRKBCRDOL_TsoNhMlbg';
const clientId = '20uxBzaeR8W1J69xL0u21Q';
const clientSecret = '23zrH9sZ8oyAzavDwojEOWNh4VgERfYf';
const hostUser = 'nenenane2@gmail.com';

async function getToken() {
  const tokenUrl = new URL('https://zoom.us/oauth/token');
  tokenUrl.searchParams.set('grant_type', 'account_credentials');
  tokenUrl.searchParams.set('account_id', accountId);
  const basic = Buffer.from(clientId + ':' + clientSecret).toString('base64');
  const resp = await fetch(tokenUrl.toString(), {
    method: 'POST',
    headers: { Authorization: 'Basic ' + basic }
  });
  return (await resp.json()).access_token;
}

async function deleteAllMeetings() {
  const token = await getToken();

  // List all scheduled meetings
  console.log('Fetching all scheduled meetings for', hostUser);
  const listResp = await fetch(
    `https://api.zoom.us/v2/users/${encodeURIComponent(hostUser)}/meetings?type=scheduled&page_size=100`,
    { headers: { Authorization: `Bearer ${token}` } }
  );

  if (listResp.status !== 200) {
    console.log('Error listing meetings:', listResp.status, await listResp.text());
    return;
  }

  const data = await listResp.json();
  const meetings = data.meetings || [];
  console.log('Found', meetings.length, 'meetings to delete\n');

  // Delete each meeting
  for (const meeting of meetings) {
    console.log('Deleting meeting', meeting.id, '-', meeting.topic);
    const delResp = await fetch(
      `https://api.zoom.us/v2/meetings/${meeting.id}`,
      {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      }
    );

    if (delResp.status === 204) {
      console.log('  ✓ Deleted');
    } else {
      console.log('  ✗ Error:', delResp.status);
    }
  }

  console.log('\n✅ All Zoom meetings cleared!');
}

deleteAllMeetings().catch(e => console.error(e));
