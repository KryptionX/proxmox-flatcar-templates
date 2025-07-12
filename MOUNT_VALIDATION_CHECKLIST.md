# Flatcar NFS Mount Validation Checklist

## 🔍 Pre-Deployment Safety Checks

### 1. **Mount Point Verification**

```bash
# Check all 9 mounts are active
findmnt -t nfs
# Expected: 9 NFS mount points

# Verify specific mounts
findmnt /mnt/speedforce
findmnt /mnt/Zephyr/Media
findmnt /mnt/immich/immichData
```

### 2. **Content Accessibility Test**

```bash
# speedforce - Configuration data
ls -la /mnt/speedforce/docker/data/
ls -la /mnt/speedforce/docker/data/downloaders/sonarr/

# Zephyr - Media libraries
ls -la /mnt/Zephyr/Media/
ls -la /mnt/Zephyr/Media/tvshows/
ls -la /mnt/Zephyr/Lynda/Movies/

# solo-ssd - Downloads
ls -la /mnt/solo-ssd/downloads/

# Immich - Gateway mounts
ls -la /mnt/immich/immichData/
ls -la /mnt/immich/database/
ls -la /mnt/immich/sync/
```

### 3. **Write Permission Test (Safe)**

```bash
# Test write to non-critical locations
touch /mnt/speedforce/test-write-$(date +%s).tmp
touch /mnt/Zephyr/Media/test-write-$(date +%s).tmp
touch /mnt/solo-ssd/test-write-$(date +%s).tmp

# Clean up test files
rm /mnt/speedforce/test-write-*.tmp
rm /mnt/Zephyr/Media/test-write-*.tmp
rm /mnt/solo-ssd/test-write-*.tmp

# Verify read-only mount (should fail)
touch /mnt/immich/sync/test-write.tmp  # Should get "Permission denied"
```

### 4. **Container Volume Test (Dry Run)**

```bash
# Test container mounts without starting services
docker run --rm -v /mnt/speedforce/docker/data/sonarr/config:/config alpine ls -la /config
docker run --rm -v /mnt/Zephyr/Media:/media alpine ls -la /media
docker run --rm -v /mnt/immich/immichData:/photos alpine ls -la /photos
```

### 5. **Service Health Validation**

```bash
# Check systemd mount units
systemctl status speedforce.mount
systemctl status zephyr-media.mount
systemctl status immich-photos.mount

# Check NFS health service
systemctl status nfs-health-check.service
journalctl -u nfs-health-check.service
```

## 🚨 **Red Flags (Stop and Fix)**

❌ **Mount points missing:**

```bash
findmnt -t nfs | wc -l
# Should show 9, if less → investigate failed mounts
```

❌ **Wrong content in mounts:**

```bash
ls /mnt/Zephyr/Media/
# Should show movies/tvshows/music, not random files
```

❌ **Write to read-only succeeds:**

```bash
touch /mnt/immich/sync/test.txt
# Should fail with "Permission denied"
```

❌ **Container can't access mounts:**

```bash
docker run --rm -v /mnt/speedforce:/test alpine ls /test
# Should show docker/ directory
```

## ✅ **Green Lights (Safe to Deploy)**

✅ All 9 NFS mounts showing in `findmnt -t nfs`  
✅ Content matches expected directory structure  
✅ Write tests work on read-write mounts  
✅ Write tests fail on read-only mounts  
✅ Container volume tests show expected content  
✅ All systemd mount units active and healthy

## 🛡️ **Data Loss Protection Summary**

**Highest Risk:** Local storage fallback if NFS mounts fail  
**Mitigation:** Always check mount health before deploying containers

**Medium Risk:** Writing to wrong NFS location  
**Mitigation:** Validate directory content matches expectations

**Lowest Risk:** Mount failures or permission issues  
**Impact:** Services won't start, but no data loss

## 🔧 **Recovery Actions**

If mounts are wrong:

1. **Stop all containers immediately**
2. **Fix mount configuration**
3. **Restart mount services**
4. **Re-run validation checklist**
5. **Restart containers only after validation passes**
