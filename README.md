# Dissertation-Project

A smart medication adherence tracking system with Flutter mobile and Vue.js web implementations.

## Running the App

### Flutter Mobile App
```bash
cd medical_adherence_tracker_app
flutter pub get
flutter run
```

### Vue.js Web App
```bash
cd medical_adherence_tracker_web
npm install
npm run dev
```

## Environment Variables

### Flutter Mobile App
Create a `.env` file in the `medical_adherence_tracker_app` directory with your Supabase credentials:

```env
SUPABASE_URL= ...
SUPABASE_ANON_KEY= ...
```

### Vue.js Web App
Create a `.env.local` file in the `medical_adherence_tracker_web` directory with your Supabase credentials:

```env
VITE_SUPABASE_URL= ...
VITE_SUPABASE_ANON_KEY= ...
```