<template>
  <div v-if="authLoading" class="loading-screen">
    <div class="spinner"></div>
  </div>
  <router-view v-else />
</template>

<script setup lang="ts">
import { authLoading, initAuth } from './stores/auth'
initAuth()
</script>
