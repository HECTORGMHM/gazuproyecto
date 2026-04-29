// Archivo de configuración e inicialización de Firebase para la app GAZU.
// Este módulo centraliza la conexión con los servicios de Firebase necesarios
// para la gestión logística de la aplicación: autenticación de usuarios (Auth)
// y almacenamiento de datos en tiempo real (Firestore).
// Exporta las instancias `db` y `auth` para ser consumidas por los demás
// módulos de la app.

// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyAP1AStvMrRMFHLWEcOC_gsjcFw8xQJ_u8",
  authDomain: "gazuproyecto.firebaseapp.com",
  projectId: "gazuproyecto",
  storageBucket: "gazuproyecto.firebasestorage.app",
  messagingSenderId: "151949139234",
  appId: "1:151949139234:web:58aa3ee81722541738d97b",
  measurementId: "G-X2K49BDYJE"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);

// Initialize Firestore and export as db for logistics management
export const db = getFirestore(app);

// Initialize Authentication and export for user management
export const auth = getAuth(app);
