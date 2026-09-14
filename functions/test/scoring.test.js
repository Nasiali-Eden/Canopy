const { calculatePoints } = require('../lib/scoring');
test('hours are validated and scored, ignoring client estimates and category bonuses', () => {
  expect(calculatePoints({type:'Time',hours:2,estimatedImpactPoints:99999,workType:'Tree Planting'})).toBe(20);
  for (const hours of [0,-1,25,NaN,Infinity,'2']) expect(() => calculatePoints({type:'Time',hours})).toThrow();
});
test('description length and duplicated material labels cannot inflate scores', () => {
  expect(calculatePoints({type:'Effort',effort:'a'.repeat(2000)})).toBe(20);
  expect(calculatePoints({type:'Materials',materials:Array(100).fill('gloves')})).toBe(20);
  expect(() => calculatePoints({type:'Materials',materials:[' ']})).toThrow();
  expect(() => calculatePoints({type:'Effort',effort:''})).toThrow();
});
