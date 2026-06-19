"use client";

import { useState, useEffect, useRef } from "react";

const TYPE_SPEED = 80;
const DELETE_SPEED = 40;
const PAUSE_AFTER_WORD = 2000;
const PAUSE_BETWEEN_WORDS = 500;

export function useTypewriter(words: string[]) {
  const [text, setText] = useState("");
  const wordIndexRef = useRef(0);
  const charIndexRef = useRef(0);
  const deletingRef = useRef(false);
  const wordsRef = useRef(words);
  wordsRef.current = words;

  useEffect(() => {
    if (!words.length) return;

    // Reset on words change
    wordIndexRef.current = 0;
    charIndexRef.current = 0;
    deletingRef.current = false;
    setText("");

    let timer: ReturnType<typeof setTimeout>;

    const tick = () => {
      const currentWords = wordsRef.current;
      if (!currentWords.length) return;

      const currentWord = currentWords[wordIndexRef.current % currentWords.length];

      if (!deletingRef.current) {
        if (charIndexRef.current < currentWord.length) {
          charIndexRef.current += 1;
          setText(currentWord.slice(0, charIndexRef.current));
          timer = setTimeout(tick, TYPE_SPEED);
        } else {
          timer = setTimeout(() => {
            deletingRef.current = true;
            tick();
          }, PAUSE_AFTER_WORD);
        }
      } else {
        if (charIndexRef.current > 0) {
          charIndexRef.current -= 1;
          setText(currentWord.slice(0, charIndexRef.current));
          timer = setTimeout(tick, DELETE_SPEED);
        } else {
          deletingRef.current = false;
          wordIndexRef.current = (wordIndexRef.current + 1) % currentWords.length;
          timer = setTimeout(tick, PAUSE_BETWEEN_WORDS);
        }
      }
    };

    timer = setTimeout(tick, 500);

    return () => clearTimeout(timer);
  }, [words]);

  return text;
}
