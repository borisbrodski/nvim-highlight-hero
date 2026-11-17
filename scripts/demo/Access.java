  Access check(User user, Resource resource) {
<<<<<<< ours
    if (user.isActive() && user.hasRole(ADMIN)) {
      audit.log("grant", user.id, resource.path);
      return Access.granted(resource, ttlSeconds);
    }
||||||| base
      if (user.isActive() && user.hasRole(ADMIN)) {
        audit.log("grant", user.id, resource.path);
        return Access.granted(resource, ttlSeconds);
      }
=======
        if (user.isActive() && user.hasRole(ADMIN)) {
            audit.log("grant", user.id, resource.path);
            return Access.granted(resourse, ttlSeconds);
        }
>>>>>>> theirs
    return Access.denied();
  }
