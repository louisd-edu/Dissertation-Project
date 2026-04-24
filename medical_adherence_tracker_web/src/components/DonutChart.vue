<template>
  <div class="donut-wrap" :style="{ width: size + 'px', height: size + 'px' }">
    <svg :width="size" :height="size" :viewBox="`0 0 ${size} ${size}`" style="transform: rotate(-90deg)">
      <circle :cx="half" :cy="half" :r="radius" fill="none" :stroke="trackColor" :stroke-width="sw" />
      <circle
        :cx="half" :cy="half" :r="radius"
        fill="none"
        :stroke="color"
        :stroke-width="sw"
        stroke-linecap="round"
        :stroke-dasharray="circumference"
        :stroke-dashoffset="offset"
        style="transition: stroke-dashoffset 0.7s ease"
      />
    </svg>
    <div class="donut-inner">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{
  percentage: number
  size?: number
  strokeWidth?: number
  color?: string
  trackColor?: string
}>(), {
  size: 140,
  strokeWidth: 14,
  color: '#34C759',
  trackColor: '#E5E7EB',
})

const sw = computed(() => props.strokeWidth)
const half = computed(() => props.size / 2)
const radius = computed(() => half.value - sw.value / 2 - 2)
const circumference = computed(() => 2 * Math.PI * radius.value)
const offset = computed(() =>
  circumference.value * (1 - Math.min(100, Math.max(0, props.percentage)) / 100)
)
</script>

<style scoped>
.donut-wrap {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.donut-inner {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}
</style>
