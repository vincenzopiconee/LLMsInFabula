# LLMs in Fabula 🐺💬

**LLMs in Fabula** is a technology-enhanced version of the classic social deduction game *Lupus in Fabula*. Developed as a project for the **Advanced User Interfaces** course at **Politecnico di Milano (2025-2026)**, this mobile application transforms passive device usage into an active, educational, and social experience.

The system acts as a virtual narrator by leveraging **Large Language Models (LLMs)** and **Generative Text-to-Speech (TTS)**, providing a personalized, immersive storytelling experience and eliminating the need for a human game master.

---

## ✨ Key Features

* **AI Virtual Narrator:** Replaces the human moderator with a generative agent that reacts to in-game events in real-time.
* **Narrator Personas:** Choose from 4 distinct storytelling styles: *Bard Storyteller, Dark Wizard, Oracle,* or *Old Folk*.
* **Face-to-Face Focus:** Intentionally excludes online voice chat to encourage physical interaction and the development of soft skills like public speaking and argumentation.
* **Adaptive Gameplay:** Includes 5 core roles (Werewolf, Farmer, Seer, Doctor, Medium) plus a dedicated **Spectator Mode** for teachers to moderate classroom sessions.
* **Fair Play Mechanics:** Features "Dummy Tasks" for passive roles during the night phase to prevent role identification based on physical movement or timing.

## 🛠️ Tech Stack

### Frontend
* **Framework:** Flutter (Android 5.0+ / iOS 11+).
* **Architecture:** Reactive, Event-Driven UI using `StreamBuilder` and a distributed Finite State Machine (FSM).

### Backend & AI
* **Database:** Firebase Realtime Database for millisecond-latency synchronization.
* **LLM:** Gemini 2.5 Flash via Vertex AI for low-latency narrative generation.
* **TTS:** Google Cloud Text-to-Speech API using generative models for emotional and stylistic vocal delivery.
* **Authentication:** Anonymous FirebaseAuth for rapid onboarding without credentials.

---

## 🎮 How to Play

1.  **Create/Join:** The lobby leader creates a room with custom timers and roles, then shares a 4-character code with friends.
2.  **Role Reveal:** Every player receives a secret role card.
3.  **Night Phase:** Players perform actions (killing, protecting, investigating) or complete "dummy tasks" on their devices.
4.  **Day Phase:** The AI Narrator recaps the night's events with a generated story and audio.
5.  **Discussion & Vote:** Players debate in person and vote to exile a suspected Werewolf.
6.  **Victory:** The game continues until one faction (Werewolves or Villagers) meets their win condition.

---

## 📊 Evaluation Results

Our pilot testing with 15 participants yielded:
* **System Usability Scale (SUS):** **88.4/100** ("Excellent" - Top 10% of digital products).
* **AI Coherence:** **4.6/5**.
* **Net Promoter Score (NPS):** **4.5/5**.

* ---

## 👥 The Team (Group 4)
* **Filippo Galletta** – Requirements Engineering, LLM Integration.
* **Vincenzo Picone** – Project Management, Backend, Software Architecture, TTS Subsystem.
* **Niccolò Sobrero** – Front-end Development, UX/UI Design.
* **Alessia Beatrice Viani** – Front-end Development, UX/UI Design.
